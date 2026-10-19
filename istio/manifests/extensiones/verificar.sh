#!/usr/bin/env bash
# Ejecuta las pruebas de las extensiones de Istio (X01-X03) contra el Gateway y
# desde los pods cliente del mesh.
#
# Variables (mismas que scripts/verificar.sh):
#   NAMESPACE        Namespace del Gateway       (por defecto: gateway-lab)
#   GATEWAY          Nombre del Gateway          (por defecto: gateway)
#   GATEWAY_ADDRESS  IP o hostname del Gateway   (por defecto: status.addresses[0].value)
#   HTTP_PORT        Puerto del listener http    (por defecto: 80)
#   DOMINIO          Dominio base                (por defecto: lab.local)
#   JWT_TOKEN        Token para X02              (por defecto: demo.jwt de muestra de Istio 1.31.2)
set -uo pipefail

NAMESPACE="${NAMESPACE:-gateway-lab}"
GATEWAY="${GATEWAY:-gateway}"
HTTP_PORT="${HTTP_PORT:-80}"
DOMINIO="${DOMINIO:-lab.local}"
# Token público firmado con la clave del JWKS de x02-jwt.yaml. Se descarga en vez
# de versionarlo para no disparar los detectores de secretos.
JWT_URL="https://raw.githubusercontent.com/istio/istio/1.31.2/security/tools/jwt/samples/demo.jwt"

if [[ -z "${JWT_TOKEN:-}" ]]; then
  JWT_TOKEN="$(curl -sf --max-time 10 "$JWT_URL")"
fi
if [[ -z "$JWT_TOKEN" ]]; then
  echo "No se pudo descargar ${JWT_URL}; definir JWT_TOKEN." >&2
  exit 2
fi

if [[ -z "${GATEWAY_ADDRESS:-}" ]]; then
  GATEWAY_ADDRESS="$(kubectl -n "$NAMESPACE" get gateway "$GATEWAY" \
    -o jsonpath='{.status.addresses[0].value}' 2>/dev/null)"
fi
if [[ -z "$GATEWAY_ADDRESS" ]]; then
  echo "Gateway ${NAMESPACE}/${GATEWAY} sin dirección en status.addresses; definir GATEWAY_ADDRESS." >&2
  exit 2
fi

echo "Gateway: ${NAMESPACE}/${GATEWAY}  Dirección: ${GATEWAY_ADDRESS}  HTTP: ${HTTP_PORT}"
echo

# peticion <host> <path> [argumentos curl...]
# Imprime headers y body de la respuesta.
peticion() {
  local host="$1.${DOMINIO}" path="$2"; shift 2
  curl -s -i --max-time 5 \
    --connect-to "${host}:80:${GATEWAY_ADDRESS}:${HTTP_PORT}" \
    "$@" "http://${host}${path}" 2>/dev/null | tr -d '\r'
}

estado() { head -n1 | awk '{print $2}'; }

# en_pod <namespace> <comando...>: ejecuta un comando en el pod cliente.
en_pod() { local ns="$1"; shift; kubectl -n "$ns" exec cliente -- "$@" 2>/dev/null; }

fallos=0; pruebas=0
pass() { printf 'PASS  %s  %s\n' "$1" "$2"; pruebas=$((pruebas + 1)); }
fail() { printf 'FAIL  %s  %s: %s\n' "$1" "$2" "$3"; pruebas=$((pruebas + 1)); fallos=$((fallos + 1)); }

# X01
d="AuthorizationPolicy: /anything/publico 200, /anything/privado 403"
c_pub="$(peticion authz /anything/publico | estado)"
c_priv="$(peticion authz /anything/privado | estado)"
if [[ "$c_pub" == 200 && "$c_priv" == 403 ]]; then
  pass X01 "$d"
else
  fail X01 "$d" "publico=${c_pub:-sin respuesta} privado=${c_priv:-sin respuesta}"
fi

# X02
d="JWT: sin token 403, token inválido 401, token válido 200"
c_sin="$(peticion jwt /headers | estado)"
c_inv="$(peticion jwt /headers -H 'Authorization: Bearer token-invalido' | estado)"
r_val="$(peticion jwt /headers -H "Authorization: Bearer ${JWT_TOKEN}")"
c_val="$(estado <<<"$r_val")"
if [[ "$c_sin" == 403 && "$c_inv" == 401 && "$c_val" == 200 ]]; then
  pass X02 "$d"
else
  fail X02 "$d" "sin=${c_sin:-sin respuesta} invalido=${c_inv:-sin respuesta} valido=${c_val:-sin respuesta}"
fi

d="JWT: claim sub enviado al backend en x-jwt-sub"
if grep -q '"X-Jwt-Sub"' <<<"$r_val" && grep -q 'testing@secure.istio.io' <<<"$r_val"; then
  pass X02 "$d"
else
  fail X02 "$d" "header x-jwt-sub ausente"
fi

# X03
total=100
v2="$(en_pod "$NAMESPACE" sh -c "v2=0; for _ in \$(seq ${total}); do
  curl -s --max-time 5 http://httpbin-v1:8080/hostname | grep -q httpbin-v2 && v2=\$((v2 + 1)); done; echo \$v2")"
v2="${v2:-0}"
d="GAMMA vía waypoint: 50/50 hacia httpbin-v1 (${v2}/${total} hacia v2)"
if (( v2 >= 30 && v2 <= 70 )); then pass X03 "$d"; else fail X03 "$d" "fuera del rango esperado 30-70"; fi

d="mTLS STRICT: cliente del mesh 200, cliente fuera del mesh rechazado"
c_mesh="$(en_pod "$NAMESPACE" curl -s -o /dev/null -w '%{http_code}' --max-time 5 http://httpbin-v2:8080/get)"
c_fuera="$(en_pod fuera-mesh curl -s -o /dev/null -w '%{http_code}' --max-time 5 "http://httpbin-v2.${NAMESPACE}:8080/get")"
# curl imprime 000 cuando la conexión es rechazada; vacío indica que el pod no existe.
if [[ "$c_mesh" == 200 && "$c_fuera" == 000 ]]; then
  pass X03 "$d"
else
  fail X03 "$d" "mesh=${c_mesh:-sin respuesta} fuera=${c_fuera:-sin respuesta}"
fi

echo
echo "Fallos: ${fallos}/${pruebas}"
exit $(( fallos > 0 ))
