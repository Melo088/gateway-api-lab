# 05. Desglose Línea por Línea del Proyecto y Arquitectura de Integración

Este documento sirve como **guía de referencia técnica y pedagógica exhaustiva**. Explica qué hace cada archivo del módulo `cilium/`, por qué es necesario, qué significa cada una de sus líneas y cómo se integran con el resto del laboratorio.

---

## Índice de Archivos Analizados
1. [`cilium/manifests/kustomization.yaml`](#1-ciliummanifestskustomizationyaml)
2. [`cilium/manifests/extensiones/x01-l7-policy.yaml`](#2-ciliummanifestsextensionesx01-l7-policyyaml)
3. [`cilium/manifests/extensiones/verificar.sh`](#3-ciliummanifestsextensionesverificarsh)
4. [`cilium/instalacion/cilium.yaml` y `lb-ipam.yaml`](#4-ciliuminstalacionciliumyaml-y-lb-ipamyaml)
5. [`cilium/instalacion/instalar-cilium.sh`](#5-ciliuminstalacioninstalar-ciliumsh)
6. [`cilium/instalacion/desplegar-todo.sh`](#6-ciliuminstalaciondesplegar-todosh)

---

## 1. `cilium/manifests/kustomization.yaml`

### Rol en el Proyecto
Es el punto de entrada declarativo para desplegar el laboratorio. Utiliza Kustomize para unir la base genérica (`comun/`) con el controlador específico de Cilium.

### Análisis Línea por Línea

```yaml
1: apiVersion: kustomize.config.k8s.io/v1beta1
2: kind: Kustomization
```
* **Líneas 1-2**: Identifican este recurso como un archivo de configuración de Kustomize soportado nativamente por `kubectl`.

```yaml
3: resources:
4:   - ../../comun
```
* **Línea 4 (`../../comun`)**: Apunta al directorio base compartido. Al procesar esta ruta relativa, Kustomize hereda en memoria:
  * El namespace `gateway-lab`.
  * Los dos despliegues de `httpbin` (`v1` y `v2`) con sus Services.
  * El recurso `Gateway` plantilla (`gateway.yaml`).
  * Los 7 escenarios `HTTPRoute` (E01 a E07).
* **Por qué es importante**: Respeta la regla de oro del repositorio: **no modificar nunca `comun/` directamente**.

```yaml
5: patches:
6:   - target:
7:       kind: Gateway
8:       name: gateway
```
* **Líneas 5-8**: Le indican a Kustomize que aplique una modificación dirigida exclusivamente al recurso `Gateway` denominado `gateway`.

```yaml
9:     patch: |-
10:       - op: replace
11:         path: /spec/gatewayClassName
12:         value: cilium
```
* **Líneas 10-12**: Modifican el campo JSON `/spec/gatewayClassName` para que tenga el valor `cilium`.
* **Impacto**: El API Server de Kubernetes notifica al operador de Cilium que este Gateway le pertenece. En respuesta, Cilium crea el Service `LoadBalancer` correspondiente y configura sus sockets eBPF y Envoy.

---

## 2. `cilium/manifests/extensiones/x01-l7-policy.yaml`

### Rol en el Proyecto
Demuestra una capacidad diferencial de Cilium que ningún otro controlador de Gateway API posee por sí solo: **aplicar políticas de seguridad L7 mediante eBPF y Envoy en el mismo agente**.

### Análisis Línea por Línea

```yaml
1: apiVersion: cilium.io/v2
2: kind: CiliumNetworkPolicy
3: metadata:
4:   name: l7-policy-httpbin
5:   namespace: gateway-lab
```
* **Líneas 1-5**: Crea una política de red avanzada (`CiliumNetworkPolicy`) que opera en el namespace `gateway-lab`.

```yaml
6: spec:
7:   endpointSelector:
8:     matchLabels:
9:       app: httpbin
10:       version: v1
```
* **Líneas 6-10**: Define el objetivo de la política. Solo se aplica a pods que tengan ambas etiquetas (`app: httpbin` y `version: v1`). Los pods de la versión `v2` quedan exentos, lo que permite comparar el comportamiento.

```yaml
11:   ingress:
12:     - fromEndpoints:
13:         - matchLabels:
14:             io.kubernetes.pod.namespace: gateway-lab
```
* **Líneas 11-14**: Permite la entrada de paquetes únicamente si provienen de endpoints dentro del namespace `gateway-lab` (el Gateway de Cilium).

```yaml
15:       toPorts:
16:         - ports:
17:             - port: "8080"
18:               protocol: TCP
```
* **Líneas 15-18**: Abre exclusivamente el puerto `8080/TCP` del contenedor.

```yaml
19:           rules:
20:             http:
21:               - method: GET
22:                 path: "/get"
23:               - method: GET
24:                 path: "/hostname"
25:               - method: GET
26:                 path: "/headers"
27:               - method: GET
28:                 path: "/status/.*"
```
* **Líneas 19-28**: Define la lista blanca HTTP en Capa 7.
* **Mecanismo Interno**: El socket TCP se conecta a un programa eBPF que inspecciona el flujo HTTP. Si la petición es un `GET` a `/get`, `/hostname`, `/headers` o `/status/*`, se permite el paso. Si alguien intenta un método `POST`, `PUT`, `DELETE` o solicita otra ruta, el agente de Cilium emite un **`403 Access Denied`** de inmediato, protegiendo al pod backend de cualquier sobrecarga.

---

## 3. `cilium/manifests/extensiones/verificar.sh`

### Rol en el Proyecto
Automatiza la comprobación de la extensión de seguridad L7 ejecutando pruebas positivas y negativas.

### Análisis Línea por Línea

```bash
1: #!/usr/bin/env bash
2: set -uo pipefail
```
* Configura Bash en modo estricto: aborta si se accede a variables sin definir y preserva errores en pipelines.

```bash
4: NAMESPACE="${NAMESPACE:-gateway-lab}"
5: GATEWAY="${GATEWAY:-gateway}"
6: HTTP_PORT="${HTTP_PORT:-80}"
7: DOMINIO="${DOMINIO:-lab.local}"
```
* Permite sobreescribir variables de entorno en caso de usar puertos alternativos o `port-forward`.

```bash
9: if [[ -z "${GATEWAY_ADDRESS:-}" ]]; then
10:   GATEWAY_ADDRESS="$(kubectl -n "$NAMESPACE" get gateway "$GATEWAY" \
11:     -o jsonpath='{.status.addresses[0].value}' 2>/dev/null || true)"
12: fi
```
* Extrae de forma dinámica la dirección IP asignada al Gateway por el balanceador o túnel.

```bash
29: code_get="$(curl -sk -o /dev/null -w "%{http_code}" --max-time 5 \
30:   --connect-to "${host}:80:${GATEWAY_ADDRESS}:${HTTP_PORT}" \
31:   "http://${host}/get" 2>/dev/null || true)"
```
* **Prueba Positiva**: Envía un `GET /get`. La política lo permite y se valida que devuelva código `200`.

```bash
40: code_post="$(curl -sk -o /dev/null -w "%{http_code}" --max-time 5 -X POST \
41:   --connect-to "${host}:80:${GATEWAY_ADDRESS}:${HTTP_PORT}" \
42:   "http://${host}/post" 2>/dev/null || true)"
```
* **Prueba Negativa**: Envía un `POST /post`. La política debe rechazarlo con un código `403` (o drop/timeout).

---

## 4. `cilium/instalacion/cilium.yaml` y `lb-ipam.yaml`

### Rol en el Proyecto
`cilium.yaml` es la configuración que lee `cilium-cli` (`cilium install -f`); `lb-ipam.yaml` da IPs a los Services `LoadBalancer`.

### `cilium.yaml`

```yaml
kubeProxyReplacement: true
k8sServiceHost: auto
```
* Cilium reemplaza a `kube-proxy` con mapas eBPF; es requisito del controlador de Gateway API.
* Sin `kube-proxy`, la dirección del API Server se obtiene del ConfigMap `cluster-info` de kubeadm.

```yaml
gatewayAPI:
  enabled: true
```
* Activa el controlador de `GatewayClass`, `Gateway` y `HTTPRoute` en `cilium-operator`; el DaemonSet `cilium-envoy` recibe los listeners por xDS.

```yaml
l2announcements:
  enabled: true
externalIPs:
  enabled: true
k8sClientRateLimit:
  qps: 10
  burst: 20
```
* El agente responde ARP por las IPs de los Services `LoadBalancer`; los anuncios usan Leases, por eso se sube el límite de peticiones al API Server.

```yaml
operator:
  replicas: 1
```
* Una réplica del operador, suficiente en un clúster de un nodo.

### `lb-ipam.yaml`
* `CiliumLoadBalancerIPPool`: rango 192.168.39.200-220, dentro de la subred por defecto del driver kvm2.
* `CiliumL2AnnouncementPolicy`: anuncia esas IPs por ARP en las interfaces `eth*` del nodo.

---

## 5. `cilium/instalacion/instalar-cilium.sh`

### Rol en el Proyecto
Descarga el CLI de Cilium oficial e instala el CNI en el clúster activo sin requerir que el usuario tenga instalado el cliente de Helm.

### Puntos Clave del Script:
* Detecta si `cilium` ya está en `$PATH`; si no, descarga la versión fijada (`CILIUM_CLI_VERSION`, v0.20.1) el archivo comprimido para la arquitectura del procesador (`amd64` o `arm64`).
* Comprueba si el directorio `/usr/local/bin` tiene permisos de escritura; si no, lo instala de forma no privilegiada en `~/.local/bin/`.
* Instala los CRDs de Gateway API si faltan, ejecuta `cilium install --version 1.20.3` con `cilium.yaml`, aplica `lb-ipam.yaml` y ejecuta `cilium status --wait` para garantizar que todos los pods estén en estado `Running` antes de continuar.

---

## 6. `cilium/instalacion/desplegar-todo.sh`

### Rol en el Proyecto
Es el **orquestador maestro** del laboratorio. Coordina las 6 fases del ciclo de vida:
1. Comprueba conectividad al clúster Minikube.
2. Aplica los CRDs de Gateway API (`v1.6.2`).
3. Instala Cilium mediante `instalar-cilium.sh`.
4. Ejecuta `scripts/crear-certificado.sh` para emitir el certificado TLS autofirmado.
5. Despliega el overlay Kustomize (`kubectl apply -k cilium/manifests`) y espera que el Gateway obtenga IP.
6. Invoca a `scripts/verificar.sh` para evaluar los 7 escenarios estándar y prueba la extensión eBPF.

Con el clúster creado según la sección 4 del README, este script deja el laboratorio desplegado y verificado con un solo comando.
