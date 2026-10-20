#!/usr/bin/env bash
# Verifica la extensión X01 (CiliumNetworkPolicy L7 con eBPF) contra el Gateway.
#
# Variables:
#   NAMESPACE        Namespace del Gateway       (por defecto: gateway-lab)
#   GATEWAY          Nombre del Gateway          (por defecto: gateway)
#   GATEWAY_ADDRESS  IP o hostname del Gateway   (por defecto: status.addresses[0].value)
#   HTTP_PORT        Puerto del listener http    (por defecto: 80)
#   DOMINIO          Dominio base                (por defecto: lab.local)
set -uo pipefail

NAMESPACE="${NAMESPACE:-gateway-lab}"
GATEWAY="${GATEWAY:-gateway}"
HTTP_PORT="${HTTP_PORT:-80}"
DOMINIO="${DOMINIO:-lab.local}"

if [[ -z "${GATEWAY_ADDRESS:-}" ]]; then
  GATEWAY_ADDRESS="$(kubectl -n "$NAMESPACE" get gateway "$GATEWAY" \
    -o jsonpath='{.status.addresses[0].value}' 2>/dev/null || true)"
fi

if [[ -z "$GATEWAY_ADDRESS" ]]; then
  echo "Gateway ${NAMESPACE}/${GATEWAY} sin dirección en status.addresses; definir GATEWAY_ADDRESS." >&2
  exit 2
fi

echo "Verificando extensión Cilium L7 en: ${GATEWAY_ADDRESS}:${HTTP_PORT}"
echo

fallos=0
pass() { printf 'PASS  %s  %s\n' "$1" "$2"; }
fail() { printf 'FAIL  %s  %s: %s\n' "$1" "$2" "$3"; fallos=$((fallos + 1)); }

host="enrutamiento.${DOMINIO}"

# Prueba 1: GET permitido por la política L7
code_get="$(curl -sk -o /dev/null -w "%{http_code}" --max-time 5 \
  --connect-to "${host}:80:${GATEWAY_ADDRESS}:${HTTP_PORT}" \
  "http://${host}/get" 2>/dev/null || true)"

if [[ "$code_get" == "200" ]]; then
  pass "X01-A" "GET /get permitido por CiliumNetworkPolicy L7 (status 200)"
else
  fail "X01-A" "GET /get debería responder 200" "status=${code_get}"
fi

# Prueba 2: POST bloqueado o denegado por la política L7 (esperado: 403 Access Denied o drop por Envoy/eBPF)
code_post="$(curl -sk -o /dev/null -w "%{http_code}" --max-time 5 -X POST \
  --connect-to "${host}:80:${GATEWAY_ADDRESS}:${HTTP_PORT}" \
  "http://${host}/post" 2>/dev/null || true)"

if [[ "$code_post" == "403" ]]; then
  pass "X01-B" "POST /post bloqueado por CiliumNetworkPolicy L7 (status ${code_post})"
else
  fail "X01-B" "POST /post debería responder 403" "status=${code_post}"
fi

echo
echo "Fallos extensión: ${fallos}/2"
exit $(( fallos > 0 ))
