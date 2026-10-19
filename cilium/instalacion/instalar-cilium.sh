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
echo " 3. Asegurando CRDs de Gateway API y compatibilidad v1alpha2"
echo "============================================================"
if ! kubectl get crd gateways.gateway.networking.k8s.io >/dev/null 2>&1; then
  echo "Instalando CRDs oficiales de Gateway API v1.6.2 (Standard)..."
  kubectl apply --server-side=true -f https://github.com/kubernetes-sigs/gateway-api/releases/download/v1.6.2/standard-install.yaml
fi

# Cilium 1.16 reconcilia TLSRoute requiriendo el endpoint v1alpha2.
# En Gateway API v1.6+, v1alpha2 viene desactivado por defecto (served=false).
# Lo activamos para que el reconciliador de cilium-operator inicie limpiamente:
if kubectl get crd tlsroutes.gateway.networking.k8s.io >/dev/null 2>&1; then
  echo "Habilitando compatibilidad con TLSRoute v1alpha2 para el operador de Cilium..."
  kubectl patch crd tlsroutes.gateway.networking.k8s.io --type=json -p '[{"op": "replace", "path": "/spec/versions/1/served", "value": true}]' 2>/dev/null || true
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
echo " 5. Estado de los componentes de Cilium"
echo "============================================================"
cilium status --wait

echo
echo "============================================================"
echo " 6. Verificando GatewayClass cilium"
echo "============================================================"
kubectl get gatewayclass cilium -o wide || true

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
