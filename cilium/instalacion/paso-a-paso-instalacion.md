# Guía Paso a Paso de Instalación y Despliegue de Cilium

Este documento detalla el procedimiento para levantar e implementar el laboratorio de **Gateway API con Cilium sin utilizar el cliente Helm**.

Se presentan dos modalidades:
1. **Modalidad Automatizada**: Utilizando los scripts incluidos en `cilium/instalacion/`.
2. **Modalidad Manual ("A Mano")**: Ejecutando comando por comando con explicaciones técnicas detalladas.

---

## 1. Prerrequisitos del Sistema

| Herramienta | Versión mínima | Verificación |
|---|---|---|
| Linux Kernel | >= 5.4 (óptimo con soporte eBPF) | `uname -r` |
| `minikube` | v1.38.0+ con driver `kvm2` (libvirt) | `minikube version`, `virsh version` |
| `kubectl` | v1.31.0+ | `kubectl version --client` |
| `curl`, `tar`, `openssl` | Estándar en Linux | `curl --version`, `openssl version` |

---

## 2. Modalidad 1: Instalación Automatizada (Recomendada)

Si deseas levantar todo el entorno de punta a punta de forma desatendida:

### Paso 1: Iniciar el Clúster de Minikube
Cilium actuará como CNI y reemplazará a `kube-proxy`, así que el clúster arranca sin ninguno de los dos:
```bash
minikube start --driver=kvm2 --cpus=2 --memory=4096 \
  --network-plugin=cni --cni=false \
  --extra-config=kubeadm.skip-phases=addon/kube-proxy
```
Se usa el driver `kvm2` (VM con kernel propio): con el driver `docker` el tráfico hacia Envoy no llega a su socket (ver `cilium/README.md`, sección 9).

No hace falta `minikube tunnel`: LB IPAM de Cilium asigna la IP del Gateway ([`lb-ipam.yaml`](lb-ipam.yaml)).

### Paso 3: Ejecutar el Script Maestro
En la terminal principal, dentro de la raíz del repositorio:
```bash
cilium/instalacion/desplegar-todo.sh
```

El script ejecutará automáticamente las 6 fases:
1. Verificación de conectividad al clúster.
2. Instalación de los CRDs oficiales de Gateway API v1.6.2 (Standard).
3. Descarga de `cilium-cli` v0.20.1, instalación de Cilium 1.20.3 con Gateway API y aplicación del pool de LB IPAM.
4. Generación del certificado autofirmado TLS (`*.lab.local`) y creación del Secret `gateway-tls`.
5. Despliegue del overlay `cilium/manifests` (Backends httpbin + Gateway + HTTPRoutes E01-E07).
6. Ejecución de la suite de pruebas `scripts/verificar.sh` y verificación de la extensión L7.

---

## 3. Modalidad 2: Instalación Manual Paso a Paso ("A Mano")

Si prefieres ejecutar y comprender cada comando de manera individual:

### Paso 1: Iniciar Minikube
```bash
minikube start --driver=kvm2 --cpus=2 --memory=4096 \
  --network-plugin=cni --cni=false \
  --extra-config=kubeadm.skip-phases=addon/kube-proxy
```
* **Explicación**: `--network-plugin=cni --cni=false` deja el clúster sin CNI (el nodo queda `NotReady` hasta instalar Cilium) y `skip-phases=addon/kube-proxy` evita instalar `kube-proxy`, cuya función asume Cilium con eBPF.

---

### Paso 2: Instalar los CRDs Oficiales de Gateway API
Los recursos de Gateway API no forman parte del núcleo estándar de Kubernetes, por lo que deben instalarse previamente:
```bash
kubectl apply --server-side=true -f https://github.com/kubernetes-sigs/gateway-api/releases/download/v1.6.2/standard-install.yaml
```
* **Verificación**:
```bash
kubectl get crd | grep gateway.networking.k8s.io
```
Deberás ver listados: `gatewayclasses`, `gateways`, `httproutes`, `grpcroutes`, `referencegrants`, `tlsroutes`, `listenersets`, entre otros. Deben instalarse **antes** que Cilium.

---

### Paso 3: Descargar el CLI Oficial de Cilium (Sin Helm)
Descargamos el binario precompilado de `cilium-cli` que contiene internamente el motor de instalación:
```bash
CILIUM_CLI_VERSION=v0.20.1
CLI_ARCH=amd64
if [ "$(uname -m)" = "aarch64" ]; then CLI_ARCH=arm64; fi

curl -L --fail --remote-name-all "https://github.com/cilium/cilium-cli/releases/download/${CILIUM_CLI_VERSION}/cilium-linux-${CLI_ARCH}.tar.gz"
tar -xzf "cilium-linux-${CLI_ARCH}.tar.gz" -C ~/.local/bin
rm -f "cilium-linux-${CLI_ARCH}.tar.gz"

cilium version --client
```

---

### Paso 4: Instalar Cilium en el Clúster
Instalamos Cilium en el namespace `kube-system` con la configuración de [`cilium.yaml`](cilium.yaml):
```bash
cilium install --version 1.20.3 -f cilium/instalacion/cilium.yaml --wait
kubectl apply -f cilium/instalacion/lb-ipam.yaml
```

* **Explicación de parámetros clave**:
  * `kubeProxyReplacement: true`: Cilium balancea los Services con mapas eBPF en lugar de `kube-proxy`.
  * `k8sServiceHost: auto`: sin `kube-proxy`, Cilium lee la dirección del API Server del ConfigMap `cluster-info`.
  * `gatewayAPI.enabled: true`: activa el controlador de Gateway API en `cilium-operator` y la `GatewayClass` `cilium`.
  * `l2announcements` y `externalIPs`: junto con `lb-ipam.yaml`, dan al Service del Gateway una IP de la subred de minikube anunciada por ARP.
* **Verificación de estado**:
```bash
cilium status --wait
kubectl get gatewayclass
```
*Debe aparecer la GatewayClass `cilium` con estado `ACCEPTED: True`.*

---

### Paso 5: Generar el Certificado TLS
El listener HTTPS en el puerto 443 requiere el Secret `gateway-tls` en el namespace `gateway-lab`:
```bash
scripts/crear-certificado.sh
```
* **Verificación**:
```bash
kubectl -n gateway-lab get secret gateway-tls
```

---

### Paso 6: Aplicar Manifiestos de Cilium
Aplicamos la base común y los escenarios adaptados mediante el overlay de Kustomize:
```bash
kubectl apply -k cilium/manifests
```
* **Verificación de recursos**:
```bash
kubectl -n gateway-lab get pods
kubectl -n gateway-lab get gateway gateway
kubectl -n gateway-lab get svc
```
Observarás que Cilium crea automáticamente un Service `LoadBalancer` llamado `cilium-gateway-gateway` y el Gateway obtendrá una IP en `status.addresses`.

---

### Paso 7: Ejecutar la Verificación de Escenarios
Ejecutamos el script de pruebas automatizado:
```bash
scripts/verificar.sh
```
El script toma la dirección de `status.addresses` del Gateway (`192.168.39.200` con el pool de `lb-ipam.yaml`).

---

### Paso 8: Probar la Extensión L7 de Cilium
```bash
kubectl apply -k cilium/manifests/extensiones
cilium/manifests/extensiones/verificar.sh
```

---

## 4. Desglose Línea por Línea de `instalar-cilium.sh`

```bash
#!/usr/bin/env bash
set -euo pipefail
```
* `set -e`: Detiene la ejecución inmediatamente si algún comando falla.
* `set -u`: Trata el uso de variables no declaradas como un error.
* `set -o pipefail`: Propaga el código de salida de un error a través de pipelines.

```bash
CILIUM_VERSION="${CILIUM_VERSION:-1.20.3}"
CILIUM_CLI_VERSION="${CILIUM_CLI_VERSION:-v0.20.1}"
VALUES_FILE="$(dirname "$0")/cilium.yaml"
LB_IPAM_FILE="$(dirname "$0")/lb-ipam.yaml"
```
* Fija las versiones de Cilium y de su CLI para garantizar reproducibilidad.
* Resuelve las rutas hacia `cilium.yaml` y `lb-ipam.yaml`.

```bash
if ! command -v cilium >/dev/null 2>&1; then
```
* Comprueba si el binario `cilium` ya está instalado en el sistema para evitar descargas innecesarias.

```bash
  CLI_ARCH="amd64"
  if [ "$(uname -m)" = "aarch64" ]; then CLI_ARCH="arm64"; fi
```
* Detecta la arquitectura de la CPU (`x86_64` o `ARM64`) para descargar el CLI fijado en `CILIUM_CLI_VERSION`.

```bash
cilium install --version "${CILIUM_VERSION}" -f "$VALUES_FILE" --wait
```
* Invoca el motor de instalación interno de Cilium CLI inyectando los valores declarativos.
* La bandera `--wait` bloquea hasta que los pods del CNI y el operador estén completamente listos y operando.

---

## 5. Limpieza Completa del Entorno

Para desmantelar todo el laboratorio y dejar el clúster limpio:
```bash
# 1. Eliminar manifiestos del laboratorio y secretos
kubectl delete -k cilium/manifests

# 2. Pool de LB IPAM y Cilium
kubectl delete -f cilium/instalacion/lb-ipam.yaml
cilium uninstall

# 3. Clúster
minikube delete
```
