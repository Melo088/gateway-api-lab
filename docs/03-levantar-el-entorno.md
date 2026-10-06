# 03 · Levantar el entorno

Esta guía es **agnóstica**: cualquier clúster de Kubernetes **1.30+** sirve.
Elige la opción que prefieras; los equipos pueden usar herramientas distintas
mientras los manifiestos sean reproducibles.

## 📋 Prerequisitos

| Herramienta | Verificación | Notas |
|---|---|---|
| `kubectl` | `kubectl version --client` | Obligatoria |
| Docker o Podman | `docker version` | Driver para clústeres locales |
| `helm` | `helm version` | Varios controladores se instalan con Helm |
| `minikube` / `kind` / `k3d` | según la opción elegida | Solo una |

## Opción A — Minikube

```bash
minikube start --driver=docker --kubernetes-version=stable
kubectl get nodes

# Los Service tipo LoadBalancer requieren (en otra terminal, dejarlo corriendo):
minikube tunnel
```

> Algunos controladores exponen el Gateway como `LoadBalancer`; sin
> `minikube tunnel` quedarán en `<pending>`. Alternativa: `minikube service`
> o `kubectl port-forward` según documente cada equipo.

## Opción B — kind

```bash
kind create cluster --name gateway-lab
kubectl get nodes
```

> En kind los `LoadBalancer` no obtienen IP externa por defecto; se suele usar
> `kubectl port-forward` hacia el Service del gateway, o instalar
> [cloud-provider-kind](https://github.com/kubernetes-sigs/cloud-provider-kind).

## Opción C — k3d

```bash
k3d cluster create gateway-lab -p "8080:80@loadbalancer"
kubectl get nodes
```

## Opción D — Clúster gestionado (nube)

GKE, EKS, AKS o cualquier clúster existente también es válido. Solo asegúrate
de tener permisos para instalar CRDs y crear namespaces.

## 🧩 Instalar los CRDs de Gateway API

Los CRDs **no vienen preinstalados** en Kubernetes:

```bash
# Canal Standard (última versión estable, v1.6.x)
kubectl apply -f https://github.com/kubernetes-sigs/gateway-api/releases/latest/download/standard-install.yaml

# Verificar
kubectl get crd | grep gateway.networking.k8s.io
```

<details>
<summary>Opciones alternativas</summary>

```bash
# Fijar una versión específica (reproducibilidad)
kubectl apply -f https://github.com/kubernetes-sigs/gateway-api/releases/download/v1.6.2/standard-install.yaml

# Canal Experimental (TCPRoute, UDPRoute, ListenerSet…) — requiere server-side
kubectl apply --server-side=true -f https://github.com/kubernetes-sigs/gateway-api/releases/latest/download/experimental-install.yaml
```

</details>

> ⚠️ **Ojo:** algunos controladores instalan sus propios CRDs de Gateway API o
> exigen que ya estén instalados. Lee el README de tu carpeta y la
> documentación oficial antes de duplicar instalaciones.

## 🎯 App de prueba sugerida (común para todos)

Para que los resultados sean comparables, sugerimos que todos expongan la
misma app de prueba ([httpbin](https://httpbin.org)):

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: httpbin
spec:
  replicas: 1
  selector:
    matchLabels:
      app: httpbin
  template:
    metadata:
      labels:
        app: httpbin
    spec:
      containers:
        - name: httpbin
          image: mccutchen/go-httpbin
          ports:
            - containerPort: 8080
---
apiVersion: v1
kind: Service
metadata:
  name: httpbin
spec:
  selector:
    app: httpbin
  ports:
    - port: 8080
      targetPort: 8080
```

```bash
kubectl apply -f app-prueba.yaml
kubectl port-forward svc/httpbin 8080:8080   # prueba directa sin gateway
curl localhost:8080/get
```

> Es una **sugerencia**, no una obligación: cada equipo puede usar otra app si
> lo justifica en su documentación.

## ✅ Verificación final del entorno

```bash
kubectl get nodes                          # clúster Ready
kubectl get crd | grep gateway             # CRDs instalados
kubectl get gatewayclass                   # (vacío hasta instalar un controlador)
```

Cuando esto esté listo, ve al `README.md` de la carpeta de tu equipo.
