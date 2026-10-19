# Manifiestos de Cilium - Explicación y Desglose Línea por Línea

Este directorio contiene los manifiestos declarativos utilizados para desplegar el laboratorio de Gateway API con **Cilium**.

---

## 1. `cilium/manifests/kustomization.yaml`

Este archivo define el **Overlay de Kustomize**. Su función es tomar la base común declarada en `../../comun` (que define el `Namespace`, los despliegues de `httpbin-v1`/`httpbin-v2` y los 7 escenarios `HTTPRoute` E01-E07) e inyectar la configuración específica del controlador Cilium sin duplicar código.

### Desglose Línea por Línea

```yaml
1: apiVersion: kustomize.config.k8s.io/v1beta1
2: kind: Kustomization
```
* **Líneas 1-2**: Declaran la versión de la API y el tipo de recurso de Kustomize (`Kustomization`), soportado de forma nativa por `kubectl` mediante el flag `-k`.

```yaml
3: resources:
4:   - ../../comun
```
* **Líneas 3-4 (`resources`)**: Importa la base compartida del repositorio (`comun/`). Esto incluye automáticamente:
  * El namespace `gateway-lab`.
  * Los Deployments y Services de `httpbin-v1` y `httpbin-v2`.
  * El recurso `Gateway` plantilla.
  * Todas las rutas `HTTPRoute` de los escenarios E01 a E07.
* **Importancia**: Garantiza el principio de inmutabilidad de la base compartida: ninguna implementación altera `comun/`.

```yaml
5: patches:
6:   - target:
7:       kind: Gateway
8:       name: gateway
```
* **Líneas 5-8 (`patches`)**: Define una regla de parcheo JSON 6902 dirigida al objeto de tipo `Gateway` con nombre `gateway`.

```yaml
9:     patch: |-
10:       - op: replace
11:         path: /spec/gatewayClassName
12:         value: cilium
```
* **Líneas 9-12**: Ejecuta una operación de reemplazo (`op: replace`) sobre el campo `/spec/gatewayClassName`, sustituyendo el marcador provisional `sin-definir` por `cilium`.
* **Por qué es crucial**: Le indica al API Server de Kubernetes que este `Gateway` debe ser gestionado exclusivamente por el controlador de Cilium (`io.cilium/gateway-controller`). A partir de este momento, Cilium observará el recurso y aprovisionará la infraestructura de red requerida (el Service de tipo `LoadBalancer`).
* **Nota sobre puertos**: A diferencia de Traefik (que requería parchar los puertos a 8000 y 8443), Cilium respeta nativamente los puertos estándar **80 (HTTP)** y **443 (HTTPS)** a través de su proxy Envoy embebido, por lo que no se requieren parches adicionales de puertos.

---

## 2. `cilium/manifests/extensiones/x01-l7-policy.yaml`

Este manifiesto implementa una extensión propietaria de Cilium mediante el Custom Resource Definition (CRD) `CiliumNetworkPolicy`. Demuestra cómo combinar la especificación estándar de Gateway API con la seguridad granular en capa 7 (L7) impulsada por **eBPF**.

### Desglose Línea por Línea

```yaml
1: apiVersion: cilium.io/v2
2: kind: CiliumNetworkPolicy
3: metadata:
4:   name: l7-policy-httpbin
5:   namespace: gateway-lab
```
* **Líneas 1-5**: Declara una política de red de Cilium (`cilium.io/v2`) aplicable en el namespace del laboratorio (`gateway-lab`).

```yaml
6: spec:
7:   endpointSelector:
8:     matchLabels:
9:       app: httpbin
10:       version: v1
```
* **Líneas 6-10 (`endpointSelector`)**: Selecciona los pods destino a proteger mediante etiquetas de Kubernetes. En este caso, selecciona únicamente los pods del despliegue `httpbin-v1`. El tráfico hacia `httpbin-v2` permanece sin restricciones.

```yaml
11:   ingress:
12:     - fromEndpoints:
13:         - matchLabels:
14:             io.kubernetes.pod.namespace: gateway-lab
```
* **Líneas 11-14 (`ingress.fromEndpoints`)**: Define las reglas de entrada. Solo permite tráfico proveniente de endpoints que pertenezcan al namespace `gateway-lab` (donde reside el Gateway y su proxy Envoy).

```yaml
15:       toPorts:
16:         - ports:
17:             - port: "8080"
18:               protocol: TCP
```
* **Líneas 15-18 (`toPorts`)**: Restringe el acceso únicamente al puerto TCP `8080` (el puerto en el que escucha el contenedor `httpbin`).

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
* **Líneas 19-28 (`rules.http`)**: Aquí es donde eBPF redirige el flujo al motor de políticas Envoy integrado en el agente de Cilium:
  * Se inspecciona el protocolo HTTP a nivel de aplicación (L7).
  * Se permite explícitamente el método `GET` en las rutas necesarias para los escenarios E01-E07 (`/get`, `/hostname`, `/headers`, `/status/*`).
  * Cualquier otra petición que no coincida con esta lista blanca (por ejemplo, un método `POST`, `PUT`, `DELETE` o una ruta no declarada) es rechazada con un código **403 Forbidden** generado directamente por el proxy de Cilium antes de llegar a la aplicación.

---

## 3. Cómo Probar e Integrar los Manifiestos

1. **Previsualizar los manifiestos renderizados por Kustomize**:
   ```bash
   kubectl kustomize cilium/manifests
   ```
2. **Aplicar la base y los escenarios**:
   ```bash
   kubectl apply -k cilium/manifests
   ```
3. **Aplicar la extensión de seguridad L7**:
   ```bash
   kubectl apply -k cilium/manifests/extensiones
   ```
4. **Verificar el funcionamiento de la extensión**:
   ```bash
   cilium/manifests/extensiones/verificar.sh
   ```
