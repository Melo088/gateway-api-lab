# Evidencias de la Implementación de Cilium

Este directorio almacena los registros de ejecución, salidas de terminal y capturas de pantalla que respaldan la implementación de Cilium Gateway API.

---

## Archivos de Evidencia Registrados

| Archivo | Comando Origen | Propósito |
|---|---|---|
| [`01-cluster-nodos.txt`](01-cluster-nodos.txt) | `kubectl get nodes -o wide` | Evidencia de clúster activo, versión del kernel Linux y runtime de contenedores. |
| [`02-crds-gateway-api.txt`](02-crds-gateway-api.txt) | `kubectl get crd \| grep gateway` | Lista de CRDs de Gateway API v1.6.2 (Standard) registrados. |
| [`03-cilium-status.txt`](03-cilium-status.txt) | `cilium status` | Estado de salud de los componentes: `cilium-operator`, `cilium` (DaemonSet) y `cilium-envoy`. |
| [`04-gateway-programmed.txt`](04-gateway-programmed.txt) | `kubectl describe gateway gateway` | Muestra condiciones `Accepted: True` y `Programmed: True` con IP asignada. |
| [`05-verificar-escenarios.txt`](05-verificar-escenarios.txt) | `scripts/verificar.sh` | Salida oficial con los 7 escenarios en estado **PASS** (0/7 fallos). |
| [`06-extension-l7.txt`](06-extension-l7.txt) | `cilium/manifests/extensiones/verificar.sh` | Validación de la política L7 con eBPF (GET permitido, POST rechazado con 403). |

---

## Cómo Actualizar las Evidencias con Capturas de Pantalla

Si prefieres sustituir o acompañar los archivos `.txt` con imágenes PNG:
1. Toma las capturas de pantalla en formato `.png`.
2. Guárdalas en este directorio con nombres en minúsculas y guiones (ej. `05-verificar-escenarios.png`), respetando el límite máximo de 2 MB por imagen según `CONTRIBUTING.md`.
3. Actualiza las referencias correspondientes en el archivo principal `cilium/README.md`.
