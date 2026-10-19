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
| `minikube` | v1.38.0+ | `minikube version` |
| `kubectl` | v1.31.0+ | `kubectl version --client` |
| `curl`, `tar`, `openssl` | Estándar en Linux | `curl --version`, `openssl version` |

---

## 2. Modalidad 1: Instalación Automatizada (Recomendada)

Si deseas levantar todo el entorno de punta a punta de forma desatendida:

### Paso 1: Iniciar el Clúster de Minikube
Debido a que Cilium actuará como CNI y reemplazará a `kube-proxy`, iniciamos Minikube delegando el CNI:
```bash
minikube start --network-plugin=cni --memory=4096 --cpus=2
```

### Paso 2: Iniciar el Túnel de Red (en otra terminal)
Minikube no asigna direcciones IP externas a los Services de tipo `LoadBalancer` sin un túnel activo:
```bash
minikube tunnel
```
*(Dejar esta terminal abierta durante toda la sesión del laboratorio).*

### Paso 3: Ejecutar el Script Maestro
En la terminal principal, dentro de la raíz del repositorio:
```bash
cilium/instalacion/desplegar-todo.sh
```

El script ejecutará automáticamente las 6 fases:
1. Verificación de conectividad al clúster.
2. Instalación de los CRDs oficiales de Gateway API v1.6.2 (Standard).
3. Descarga de `cilium-cli` e instalación de Cilium con eBPF y Gateway API.
4. Generación del certificado autofirmado TLS (`*.lab.local`) y creación del Secret `gateway-tls`.
5. Despliegue del overlay `cilium/manifests` (Backends httpbin + Gateway + HTTPRoutes E01-E07).
6. Ejecución de la suite de pruebas `scripts/verificar.sh` y verificación de la extensión L7.

---

## 3. Modalidad 2: Instalación Manual Paso a Paso ("A Mano")

Si prefieres ejecutar y comprender cada comando de manera individual:

### Paso 1: Iniciar Minikube
```bash
minikube start --network-plugin=cni --memory=4096 --cpus=2
```
* **Explicación**: El parámetro `--network-plugin=cni` instruye a Kubernetes para que no inicialice un CNI básico por defecto, dejando la red lista para ser configurada por Cilium vía eBPF.

En otra terminal:
```bash
minikube tunnel
```

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
Deberás ver listados: `gatewayclasses`, `gateways`, `httproutes`, `grpcroutes`, `referencegrants`, entre otros.

---

### Paso 3: Descargar el CLI Oficial de Cilium (Sin Helm)
Descargamos el binario precompilado de `cilium-cli` que contiene internamente el motor de instalación:
```bash
CILIUM_CLI_VERSION=$(curl -s https://raw.githubusercontent.com/cilium/cilium-cli/main/stable.txt)
CLI_ARCH=amd64
if [ "$(uname -m)" = "aarch64" ]; then CLI_ARCH=arm64; fi

curl -L --fail --remote-name-all "https://github.com/cilium/cilium-cli/releases/download/${CILIUM_CLI_VERSION}/cilium-linux-${CLI_ARCH}.tar.gz"
tar -xzf "cilium-linux-${CLI_ARCH}.tar.gz" -C ~/.local/bin
rm -f "cilium-linux-${CLI_ARCH}.tar.gz"

cilium version --client
```

---

### Paso 4: Instalar Cilium en el Clúster
Instalamos Cilium en el namespace `kube-system` con soporte para Gateway API y eBPF habilitados:
```bash
cilium install \
  --version 1.16.2 \
  -f cilium/instalacion/values.yaml \
  --wait
```
*O equivalentemente usando banderas directas:*
```bash
cilium install \
  --version 1.16.2 \
  --set kubeProxyReplacement=true \
  --set gatewayAPI.enabled=true \
  --wait
```

* **Explicación de parámetros clave**:
  * `kubeProxyReplacement=true`: Reemplaza la tabla de iptables y `kube-proxy` por mapas eBPF de alto rendimiento en el kernel.
  * `gatewayAPI.enabled=true`: Activa el controlador interno de Gateway API dentro de Cilium Operator y configura los listeners de Envoy embebidos.
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
*Si estás usando port-forward manual:*
```bash
kubectl -n gateway-lab port-forward svc/cilium-gateway-gateway 8080:80 8443:443 &
GATEWAY_ADDRESS=127.0.0.1 HTTP_PORT=8080 HTTPS_PORT=8443 scripts/verificar.sh
```

---

### Paso 8: Probar la Extensión L7 de Cilium
```bash
kubectl apply -k cilium/manifests/extensiones
cilium/manifests/extensiones/verificar.sh
```

---

## 4. Desglose Línea por Línea de `instalar-cilium.sh`

```bash
1: #!/usr/bin/env bash
2: set -euo pipefail
```
* `set -e`: Detiene la ejecución inmediatamente si algún comando falla.
* `set -u`: Trata el uso de variables no declaradas como un error.
* `set -o pipefail`: Propaga el código de salida de un error a través de pipelines.

```bash
4: CILIUM_VERSION="${CILIUM_VERSION:-1.16.2}"
5: VALUES_FILE="$(dirname "$0")/values.yaml"
```
* Define la versión fijada de Cilium para garantizar reproducibilidad.
* Resuelve la ruta relativa hacia `values.yaml`.

```bash
11: if ! command -v cilium >/dev/null 2>&1; then
```
* Comprueba si el binario `cilium` ya está instalado en el sistema para evitar descargas innecesarias.

```bash
13:   CILIUM_CLI_VERSION=$(curl -s https://raw.githubusercontent.com/cilium/cilium-cli/main/stable.txt)
14:   CLI_ARCH="amd64"
15:   if [ "$(uname -m)" = "aarch64" ]; then CLI_ARCH="arm64"; fi
```
* Consulta la última versión estable del CLI y detecta dinámicamente la arquitectura de la CPU (`x86_64` o `ARM64`).

```bash
47: cilium install --version "${CILIUM_VERSION}" -f "$VALUES_FILE" --wait
```
* Invoca el motor de instalación interno de Cilium CLI inyectando los valores declarativos.
* La bandera `--wait` bloquea hasta que los pods del CNI y el operador estén completamente listos y operando.

---

## 5. Limpieza Completa del Entorno

Para desmantelar todo el laboratorio y dejar el clúster limpio:
```bash
# 1. Eliminar manifiestos del laboratorio y secretos
kubectl delete -k cilium/manifests

# 2. Desinstalar Cilium del clúster
cilium uninstall

# 3. Detener Minikube
minikube stop
```
