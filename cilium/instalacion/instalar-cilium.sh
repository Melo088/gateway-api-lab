#!/usr/bin/env bash
# ==============================================================================
# Script: cilium/instalacion/instalar-cilium.sh
# Propósito: Instala Cilium en el clúster activo SIN requerir el cliente Helm,
#           utilizando el binario nativo oficial cilium-cli con soporte para
#           Gateway API (v1.6.2) y reemplazo de kube-proxy con eBPF.
# ==============================================================================
set -euo pipefail

CILIUM_VERSION="${CILIUM_VERSION:-1.16.2}"
VALUES_FILE="$(dirname "$0")/values.yaml"

echo "============================================================"
echo " 1. Verificando o Instalando Cilium CLI en el sistema"
echo "============================================================"

if ! command -v cilium >/dev/null 2>&1; then
  echo "Cilium CLI no detectado en PATH. Descargando versión estable oficial..."
  CILIUM_CLI_VERSION=$(curl -s https://raw.githubusercontent.com/cilium/cilium-cli/main/stable.txt)
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
  echo "Por favor inicia tu clúster (ej. minikube start --network-plugin=cni) antes de continuar." >&2
  exit 1
fi
echo "Conexión a Kubernetes confirmada."

echo
echo "============================================================"
echo " 3. Instalando Cilium v${CILIUM_VERSION} con Gateway API y eBPF"
echo "============================================================"
if [ -f "$VALUES_FILE" ]; then
  echo "Aplicando configuración declarativa desde: ${VALUES_FILE}"
  cilium install \
    --version "${CILIUM_VERSION}" \
    -f "$VALUES_FILE" \
    --wait
else
  echo "Aplicando configuración por flags directas de CLI..."
  cilium install \
    --version "${CILIUM_VERSION}" \
    --set kubeProxyReplacement=true \
    --set gatewayAPI.enabled=true \
    --wait
fi

echo
echo "============================================================"
echo " 4. Estado de los componentes de Cilium"
echo "============================================================"
cilium status --wait

echo
echo "============================================================"
echo " 5. Verificando GatewayClass cilium"
echo "============================================================"
kubectl get gatewayclass cilium -o wide || true

echo
echo "Cilium ha sido instalado exitosamente con soporte para Gateway API."
