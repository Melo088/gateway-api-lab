#!/usr/bin/env bash
# Ejecuta las pruebas de los escenarios de comun/escenarios contra el Gateway.
#
# Variables:
#   NAMESPACE        Namespace del Gateway       (por defecto: gateway-lab)
#   GATEWAY          Nombre del Gateway          (por defecto: gateway)
#   GATEWAY_ADDRESS  IP o hostname del Gateway   (por defecto: status.addresses[0].value)
#   HTTP_PORT        Puerto del listener http    (por defecto: 80)
#   HTTPS_PORT       Puerto del listener https   (por defecto: 443)
#   DOMINIO          Dominio base                (por defecto: lab.local)
#
# Con kubectl port-forward:
#   GATEWAY_ADDRESS=127.0.0.1 HTTP_PORT=8080 HTTPS_PORT=8443 scripts/verificar.sh
set -uo pipefail

NAMESPACE="${NAMESPACE:-gateway-lab}"
GATEWAY="${GATEWAY:-gateway}"
HTTP_PORT="${HTTP_PORT:-80}"
HTTPS_PORT="${HTTPS_PORT:-443}"
DOMINIO="${DOMINIO:-lab.local}"

if [[ -z "${GATEWAY_ADDRESS:-}" ]]; then
  GATEWAY_ADDRESS="$(kubectl -n "$NAMESPACE" get gateway "$GATEWAY" \
    -o jsonpath='{.status.addresses[0].value}' 2>/dev/null)"
fi
if [[ -z "$GATEWAY_ADDRESS" ]]; then
  echo "Gateway ${NAMESPACE}/${GATEWAY} sin dirección en status.addresses; definir GATEWAY_ADDRESS." >&2
  exit 2
fi

echo "Gateway: ${NAMESPACE}/${GATEWAY}  Dirección: ${GATEWAY_ADDRESS}  HTTP: ${HTTP_PORT}  HTTPS: ${HTTPS_PORT}"
echo

# peticion <esquema> <host> <path> [argumentos curl...]
# Imprime headers y body de la respuesta.
peticion() {
  local esquema="$1" host="$2.${DOMINIO}" path="$3"; shift 3
  local puerto="$HTTP_PORT" puerto_url=80
  if [[ "$esquema" == https ]]; then puerto="$HTTPS_PORT"; puerto_url=443; fi
  curl -sk -i --max-time 5 \
    --connect-to "${host}:${puerto_url}:${GATEWAY_ADDRESS}:${puerto}" \
    "$@" "${esquema}://${host}${path}" 2>/dev/null | tr -d '\r'
}

estado() { head -n1 | awk '{print $2}'; }

fallos=0
pass() { printf 'PASS  %s  %s\n' "$1" "$2"; }
fail() { printf 'FAIL  %s  %s: %s\n' "$1" "$2" "$3"; fallos=$((fallos + 1)); }

# E01
d="Enrutamiento por hostname y path"
c="$(peticion http enrutamiento /get | estado)"
if [[ "$c" == 200 ]]; then pass E01 "$d"; else fail E01 "$d" "status=${c:-sin respuesta}"; fi

# E02
d="Matching por header x-version"
r_v2="$(peticion http match /hostname -H 'x-version: v2')"
r_v1="$(peticion http match /hostname)"
if grep -q 'httpbin-v2' <<<"$r_v2" && grep -q 'httpbin-v1' <<<"$r_v1"; then
  pass E02 "$d"
else
  fail E02 "$d" "se esperaba v2 con header y v1 sin header"
fi

# E03
total=100; v2=0
for _ in $(seq "$total"); do
  r="$(peticion http pesos /hostname)"
  if grep -q 'httpbin-v2' <<<"$r"; then v2=$((v2 + 1)); fi
done
d="Pesos 80/20 (${v2}/${total} hacia v2)"
if (( v2 >= 8 && v2 <= 35 )); then pass E03 "$d"; else fail E03 "$d" "fuera del rango esperado 8-35"; fi

# E04
d="Modificación de headers de petición y respuesta"
r="$(peticion http headers /headers)"
if grep -qi '"x-gateway-lab"' <<<"$r" && grep -qi '^x-gateway-lab: response' <<<"$r"; then
  pass E04 "$d"
else
  fail E04 "$d" "header ausente en petición o respuesta"
fi

# E05
d="Rewrite /api/<ruta> hacia /<ruta>"
c="$(peticion http rewrite /api/status/200 | estado)"
if [[ "$c" == 200 ]]; then pass E05 "$d"; else fail E05 "$d" "status=${c:-sin respuesta}"; fi

# E06
d="Redirección HTTP a HTTPS (301)"
r="$(peticion http redirect /get)"
c="$(estado <<<"$r")"
if [[ "$c" == 301 ]] && grep -qi "^location: https://redirect.${DOMINIO}" <<<"$r"; then
  pass E06 "$d"
else
  fail E06 "$d" "status=${c:-sin respuesta}"
fi

# E07
d="Terminación TLS"
c="$(peticion https tls /get | estado)"
if [[ "$c" == 200 ]]; then pass E07 "$d"; else fail E07 "$d" "status=${c:-sin respuesta}"; fi

echo
echo "Fallos: ${fallos}/7"
exit $(( fallos > 0 ))
