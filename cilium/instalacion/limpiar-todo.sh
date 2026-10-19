#!/usr/bin/env bash
# ==============================================================================
# Script: cilium/instalacion/limpiar-todo.sh
# Propósito: Desmantela y limpia de forma ordenada todos los componentes del
#           laboratorio: extensiones, manifiestos de Gateway API, secretos TLS,
#           y desinstala el CNI Cilium del clúster.
# ==============================================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"

echo "============================================================"
echo " [PASO 1/4] Eliminando Extensión L7 de Cilium"
echo "============================================================"
if kubectl get ns gateway-lab >/dev/null 2>&1; then
  kubectl delete -k "${REPO_ROOT}/cilium/manifests/extensiones" --ignore-not-found=true
fi

echo
echo "============================================================"
echo " [PASO 2/4] Eliminando Manifiestos de Cilium y Namespace gateway-lab"
echo "============================================================"
if kubectl get ns gateway-lab >/dev/null 2>&1; then
  kubectl delete -k "${REPO_ROOT}/cilium/manifests" --ignore-not-found=true
fi

echo
echo "============================================================"
echo " [PASO 3/4] Desinstalando Cilium del Clúster"
echo "============================================================"
if command -v cilium >/dev/null 2>&1; then
  cilium uninstall || true
else
  echo "cilium CLI no encontrado en PATH, omitiendo cilium uninstall."
fi

echo
echo "============================================================"
echo " [PASO 4/4] Limpieza de Recursos Locales"
echo "============================================================"
echo "El entorno de Kubernetes ha sido limpiado exitosamente."
echo
echo "Acciones opcionales recomendadas para apagar el clúster local:"
echo "  1. Cerrar la terminal que esté ejecutando 'minikube tunnel' (Ctrl + C)."
echo "  2. Detener la máquina virtual de Minikube:"
echo "       minikube stop"
echo "  3. Si deseas eliminar el clúster por completo para liberar espacio en disco:"
echo "       minikube delete"
echo "============================================================"
