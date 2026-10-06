#!/usr/bin/env bash
# Genera un certificado autofirmado para *.lab.local y crea el Secret TLS
# referenciado por el listener https del Gateway.
#
# Variables:
#   NAMESPACE  Namespace del Gateway (por defecto: gateway-lab)
#   SECRET     Nombre del Secret     (por defecto: gateway-tls)
#   DOMINIO    Dominio base          (por defecto: lab.local)
set -euo pipefail

NAMESPACE="${NAMESPACE:-gateway-lab}"
SECRET="${SECRET:-gateway-tls}"
DOMINIO="${DOMINIO:-lab.local}"

tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT

openssl req -x509 -newkey rsa:2048 -nodes -days 365 \
  -keyout "$tmp/tls.key" -out "$tmp/tls.crt" \
  -subj "/CN=*.${DOMINIO}" \
  -addext "subjectAltName=DNS:*.${DOMINIO},DNS:${DOMINIO}" 2>/dev/null

kubectl create namespace "$NAMESPACE" --dry-run=client -o yaml | kubectl apply -f -
kubectl -n "$NAMESPACE" create secret tls "$SECRET" \
  --cert="$tmp/tls.crt" --key="$tmp/tls.key" \
  --dry-run=client -o yaml | kubectl apply -f -
