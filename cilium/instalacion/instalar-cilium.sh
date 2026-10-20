#!/usr/bin/env bash
# ==============================================================================
# Script: cilium/instalacion/instalar-cilium.sh
# Propósito: Instala Cilium en el clúster activo SIN requerir el cliente Helm,
#           utilizando el binario nativo oficial cilium-cli con soporte para
#           Gateway API (v1.6.2) y reemplazo de kube-proxy con eBPF.
# ==============================================================================
set -euo pipefail

CILIUM_VERSION="${CILIUM_VERSION:-1.20.3}"
CILIUM_CLI_VERSION="${CILIUM_CLI_VERSION:-v0.20.1}"
VALUES_FILE="$(dirname "$0")/cilium.yaml"
LB_IPAM_FILE="$(dirname "$0")/lb-ipam.yaml"

echo "============================================================"
echo " 1. Verificando o Instalando Cilium CLI en el sistema"
echo "============================================================"

if ! command -v cilium >/dev/null 2>&1; then
  echo "Cilium CLI no detectado en PATH. Descargando versión estable oficial..."
  CLI_ARCH="amd64"
  if [ "$(uname -m)" = "aarch64" ]; then CLI_ARCH="arm64"; fi

  TARGET_DIR="/usr/local/bin"
  if [ ! -w "$TARGET_DIR" ]; then
    TARGET_DIR="${HOME}/.local/bin"
    mkdir -p "$TARGET_DIR"
  fi

  echo "Descargando cilium-cli ${CILIUM_CLI_VERSION} para ${CLI_ARCH} en ${TARGET_DIR}..."
  curl -L --fail --remote-name-all "https://github.com/cilium/cilium-cli/releases/download/${CILIUM_CLI_VERSION}/cilium-linux-${CLI_ARCH}.tar.gz"
  tar -xzf "cilium-linux-${CLI_ARCH}.tar.gz" -C "$TARGET_DIR"
  rm -f "cilium-linux-${CLI_ARCH}.tar.gz"
  export PATH="${TARGET_DIR}:${PATH}"
fi

echo "Cilium CLI version:"
cilium version --client

echo
echo "============================================================"
echo " 2. Verificando conexión al clúster Kubernetes"
echo "============================================================"
if ! kubectl cluster-info >/dev/null 2>&1; then
  echo "ERROR: No hay conexión con el clúster Kubernetes." >&2
  echo "Inicia el clúster sin CNI ni kube-proxy (ver cilium/README.md, sección 4) antes de continuar." >&2
  exit 1
fi
echo "Conexión a Kubernetes confirmada."

echo
echo "============================================================"
echo " 3. Asegurando CRDs de Gateway API v1.6.2"
echo "============================================================"
# Deben existir antes de instalar Cilium: el operador solo registra la
# GatewayClass cilium si encuentra los CRDs al arrancar.
if ! kubectl get crd gateways.gateway.networking.k8s.io >/dev/null 2>&1; then
  echo "Instalando CRDs oficiales de Gateway API v1.6.2 (Standard)..."
  kubectl apply --server-side=true -f https://github.com/kubernetes-sigs/gateway-api/releases/download/v1.6.2/standard-install.yaml
fi

echo
echo "============================================================"
echo " 4. Instalando Cilium v${CILIUM_VERSION} con Gateway API y eBPF"
echo "============================================================"

# Si existe una instalación previa en estado fallido, desinstalamos limpiamente:
if cilium status 2>&1 | grep -qi "error"; then
  echo "Detectada instalación previa con errores. Limpiando antes de reinstalar..."
  cilium uninstall >/dev/null 2>&1 || true
fi

echo "Aplicando configuración declarativa desde: ${VALUES_FILE}"
cilium install \
  --version "${CILIUM_VERSION}" \
  -f "$VALUES_FILE" \
  --wait

echo
echo "============================================================"
echo " 5. Estado de los componentes de Cilium"
echo "============================================================"
cilium status --wait

echo
echo "============================================================"
echo " 6. Verificando GatewayClass cilium"
echo "============================================================"
kubectl get gatewayclass cilium -o wide || true

echo
echo "============================================================"
echo " 7. Pool de IPs para Services LoadBalancer (LB IPAM + L2)"
echo "============================================================"
kubectl apply -f "$LB_IPAM_FILE"

# Si ya existían pods en gateway-lab antes de instalar Cilium, los reiniciamos
# para que obtengan conectividad administrada por el CNI:
if kubectl get ns gateway-lab >/dev/null 2>&1; then
  if kubectl -n gateway-lab get deployment httpbin-v1 >/dev/null 2>&1; then
    echo "Reiniciando pods de httpbin para vincularlos al nuevo CNI Cilium..."
    kubectl -n gateway-lab rollout restart deployment httpbin-v1 httpbin-v2 >/dev/null 2>&1 || true
  fi
fi

echo
echo "Cilium ha sido instalado exitosamente con soporte para Gateway API."
