# 03. Preparación del entorno

Aplica a cualquier clúster Kubernetes 1.31 o superior (requisito de la
validación CEL de `TLSRoute` en Gateway API v1.5+).

## Requisitos

| Herramienta | Verificación |
|---|---|
| `kubectl` | `kubectl version --client` |
| `helm` | `helm version` |
| Runtime de contenedores (clúster local) | `docker version` o `podman version` |
| Herramienta de clúster | `minikube`, `kind`, `k3d` o clúster gestionado |

## Clúster

### Minikube

```bash
minikube start --driver=docker
minikube tunnel        # en otra terminal; asigna IP a Services LoadBalancer
```

### kind

```bash
kind create cluster --name gateway-lab
```

Los Services `LoadBalancer` no reciben IP externa sin
[cloud-provider-kind](https://github.com/kubernetes-sigs/cloud-provider-kind) o
equivalente. Alternativa: `kubectl port-forward`.

### k3d

```bash
k3d cluster create gateway-lab --k3s-arg "--disable=traefik@server:0"
```

k3s instala Traefik por defecto; se deshabilita para evitar conflictos con el
controlador bajo prueba.

### Clúster gestionado

GKE, EKS, AKS u otro. Requiere permisos para instalar CRDs, crear namespaces y
Services `LoadBalancer`.

### Verificación

```bash
kubectl get nodes
```

## CRDs de Gateway API

Kubernetes no incluye los CRDs de Gateway API. Se instala un solo canal; fijar
la versión garantiza reproducibilidad.

```bash
# Canal Standard
kubectl apply --server-side=true -f https://github.com/kubernetes-sigs/gateway-api/releases/download/v1.6.2/standard-install.yaml

# Canal Experimental (campos y recursos en desarrollo)
kubectl apply --server-side=true -f https://github.com/kubernetes-sigs/gateway-api/releases/download/v1.6.2/experimental-install.yaml
```

```bash
kubectl get crd | grep gateway.networking.k8s.io
```

Algunos controladores instalan sus propios CRDs de Gateway API o exigen una
versión específica. Cada implementación documenta la versión requerida.

## Verificación del entorno

```bash
kubectl get nodes
kubectl get crd | grep gateway.networking.k8s.io
kubectl get gatewayclass       # vacío hasta instalar un controlador
```

Siguiente paso: instalar el controlador según el README de la implementación y
ejecutar los escenarios de [`04-escenarios.md`](04-escenarios.md).
