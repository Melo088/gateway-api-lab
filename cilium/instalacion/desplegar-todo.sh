#!/usr/bin/env bash
# ==============================================================================
# Script: cilium/instalacion/desplegar-todo.sh
# Propósito: Automatiza el despliegue COMPLETO de Cilium Gateway API,
#           desde la instalación de CRDs hasta la validación de los 7 escenarios
#           (E01-E07) y la extensión de seguridad L7 con eBPF.
#
# Prerrequisitos:
#   - Clúster sin CNI ni kube-proxy (cilium/README.md, sección 4):
#       minikube start --driver=kvm2 --network-plugin=cni --cni=false \
#         --extra-config=kubeadm.skip-phases=addon/kube-proxy
# ==============================================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"

echo "============================================================"
echo " [FASE 1/6] Verificando conexión al clúster Kubernetes"
echo "============================================================"
if ! kubectl cluster-info >/dev/null 2>&1; then
  echo "ERROR: No hay clúster activo. Inicia minikube antes de ejecutar este script:" >&2
  echo "  minikube start --driver=kvm2 --cpus=2 --memory=4096 --network-plugin=cni --cni=false --extra-config=kubeadm.skip-phases=addon/kube-proxy" >&2
  exit 1
fi
kubectl get nodes -o wide

echo
echo "============================================================"
echo " [FASE 2/6] Instalando CRDs de Gateway API (v1.6.2 Standard)"
echo "============================================================"
kubectl apply --server-side=true -f https://github.com/kubernetes-sigs/gateway-api/releases/download/v1.6.2/standard-install.yaml
echo "CRDs registrados:"
kubectl get crd | grep gateway.networking.k8s.io || true

echo
echo "============================================================"
echo " [FASE 3/6] Instalando Cilium CNI (sin Helm)"
echo "============================================================"
"${SCRIPT_DIR}/instalar-cilium.sh"

echo
echo "============================================================"
echo " [FASE 4/6] Generando Certificado TLS para el Listener HTTPS"
echo "============================================================"
cd "${REPO_ROOT}"
"${REPO_ROOT}/scripts/crear-certificado.sh"

echo
echo "============================================================"
echo " [FASE 5/6] Aplicando Base Común y Escenarios con Overlay Cilium"
echo "============================================================"
kubectl apply -k "${REPO_ROOT}/cilium/manifests"

echo "Esperando que los despliegues de httpbin estén listos..."
kubectl -n gateway-lab rollout status deployment/httpbin-v1 --timeout=120s
kubectl -n gateway-lab rollout status deployment/httpbin-v2 --timeout=120s

echo "Esperando que el Gateway obtenga dirección IP externa (LB IPAM de Cilium)..."
for i in {1..30}; do
  ADDR=$(kubectl -n gateway-lab get gateway gateway -o jsonpath='{.status.addresses[0].value}' 2>/dev/null || true)
  if [[ -n "$ADDR" ]]; then
    echo "Gateway obtuvo dirección IP: ${ADDR}"
    break
  fi
  echo "Intento ${i}/30: Esperando asignación de IP en status.addresses..."
  sleep 3
done

kubectl -n gateway-lab get gateway,svc,httproute

echo
echo "============================================================"
echo " [FASE 6/6] Ejecutando Pruebas de Verificación (E01 a E07)"
echo "============================================================"
if ! "${REPO_ROOT}/scripts/verificar.sh"; then
  echo "ADVERTENCIA: si falló por falta de IP externa, revisar el pool de cilium/instalacion/lb-ipam.yaml"
  echo "  (debe pertenecer a la subred de 'minikube ip')."
fi

echo
echo "============================================================"
echo " [OPCIONAL] Desplegando y Verificando Extensión L7 de Cilium"
echo "============================================================"
kubectl apply -k "${REPO_ROOT}/cilium/manifests/extensiones"
"${REPO_ROOT}/cilium/manifests/extensiones/verificar.sh" || true

echo
echo "============================================================"
echo " DESPLIEGUE Y VERIFICACIÓN COMPLETADOS EXITOSAMENTE"
echo "============================================================"
