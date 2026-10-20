# Evidencias de la Implementación de Cilium

Este directorio almacena los registros de ejecución, salidas de terminal y capturas de pantalla que respaldan la implementación de Cilium Gateway API.

---

## Archivos de Evidencia Registrados

| Archivo | Comando Origen | Propósito |
|---|---|---|
| [`01-cluster-nodos.txt`](01-cluster-nodos.txt) | `kubectl get nodes -o wide`, `kubectl -n kube-system get ds kube-proxy` | Nodo minikube kvm2 (kernel 6.6.95, Kubernetes v1.35.1) sin `kube-proxy`. |
| [`02-crds-gateway-api.txt`](02-crds-gateway-api.txt) | `kubectl get crd \| grep gateway` | CRDs de Gateway API registrados y `bundle-version` v1.6.2. |
| [`03-cilium-status.txt`](03-cilium-status.txt) | `cilium status`, `cilium-dbg status` | Cilium 1.20.3 en `OK`, reemplazo de kube-proxy y proxy L7 activos. |
| [`04-gateway-programmed.txt`](04-gateway-programmed.txt) | `kubectl get gatewayclass`, `kubectl -n gateway-lab get gateway,svc,httproute` | GatewayClass aceptada, pool de LB IPAM y Gateway `Programmed` con `192.168.39.200`. |
| [`05-verificar-escenarios.txt`](05-verificar-escenarios.txt) | `scripts/verificar.sh` | Salida oficial con los 7 escenarios en estado **PASS** (0/7 fallos). |
| [`06-extension-l7.txt`](06-extension-l7.txt) | `cilium/manifests/extensiones/verificar.sh` | Política L7: GET permitido (200), POST rechazado (403); sin la política, el POST da 200. |

---

## Cómo Actualizar las Evidencias con Capturas de Pantalla

Si prefieres sustituir o acompañar los archivos `.txt` con imágenes PNG:
1. Toma las capturas de pantalla en formato `.png`.
2. Guárdalas en este directorio con nombres en minúsculas y guiones (ej. `05-verificar-escenarios.png`), respetando el límite máximo de 2 MB por imagen según `CONTRIBUTING.md`.
3. Actualiza las referencias correspondientes en el archivo principal `cilium/README.md`.
