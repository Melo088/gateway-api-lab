# 04. Problemas Encontrados y Soluciones (Guía de Troubleshooting)

Esta guía documenta los problemas, advertencias y comportamientos anómalos encontrados durante el despliegue de **Cilium Gateway API**, junto con su causa raíz, comandos de diagnóstico y solución paso a paso.

---

## Matriz Resumen de Incidencias

| # | Síntoma / Error | Causa Raíz | Nivel de Severidad | Solución Rápida |
|---|---|---|---|---|
| **1** | Gateway en `PROGRAMMED: False` y Service en `<pending>` | Minikube no asigna IP externa a Services `LoadBalancer` sin túnel activo | Alta | Iniciar `minikube tunnel` o usar `port-forward` |
| **2** | Error `no matches for kind "Gateway"` al aplicar kustomize | Los CRDs oficiales de Gateway API no fueron instalados | Crítica | Aplicar `standard-install.yaml` v1.6.2 |
| **3** | Handshake TLS falla en E07 (`curl: (35) error...`) | Secret `gateway-tls` ausente en el namespace `gateway-lab` | Alta | Ejecutar `scripts/crear-certificado.sh` |
| **4** | Cilium Agent en `CrashLoopBackOff` o `Error` | Conflicto con `kube-proxy` existente o cgroups v2 no montados | Crítica | Iniciar Minikube con `--network-plugin=cni` |
| **5** | E05 (Rewrite) devuelve `404 Not Found` | Reemplazo de prefijo desalineado con las rutas de `httpbin` | Media | Verificar `ReplacePrefixMatch: /` en `e05-rewrite.yaml` |
| **6** | `Error: namespaces "cilium-secrets" not found` al instalar | Directiva `secretsNamespace.create: false` en `values.yaml` sin namespace existente | Alta | Omitir `secretsNamespace` o poner `create: true` |
| **7** | `release name check failed: cannot reuse a name that is still in use` | Intento previo de instalación falló a medio camino dejando release rota | Media | Ejecutar `cilium uninstall` antes de reinstalar |
| **8** | `cilium-operator` en CrashLoopBackOff: `no matches for kind "TLSRoute" in version "v1alpha2"` | Gateway API v1.6.2 deshabilita `v1alpha2` (`served: false`), requerido por Cilium 1.16 | Crítica | Parchar el CRD `tlsroutes` para habilitar `served: true` en `v1alpha2` |
| **9** | `CiliumNetworkPolicy` no bloquea o pods no reciben CNI | Los pods de `httpbin` se levantaron antes de que Cilium estuviese listo | Media | Ejecutar `rollout restart` sobre los Deployments |
| **10**| Extensión L7 bloquea al Gateway (`status=000` o timeout) | La política L7 usa `fromEndpoints` y desconoce la identidad `reserved:ingress` | Alta | Usar `fromEntities: [ingress, cluster, host]` |

---

## Diagnóstico Detallado y Solución

### Incidencia 1: El Gateway no obtiene dirección IP externa (`<pending>`)
* **Síntoma**: Al ejecutar `kubectl -n gateway-lab get gateway gateway`, la columna `PROGRAMMED` muestra `False` y la columna `ADDRESSES` está vacía.
* **Causa Raíz**: En Minikube con driver Docker, Kubernetes no cuenta con un proveedor de nube que asigne IP pública automáticamente.
* **Solución**:
  1. En una terminal separada, ejecutar `minikube tunnel`.
  2. Alternativa con port-forward:
     ```bash
     kubectl -n gateway-lab port-forward svc/cilium-gateway-gateway 8080:80 8443:443 &
     GATEWAY_ADDRESS=127.0.0.1 HTTP_PORT=8080 HTTPS_PORT=8443 scripts/verificar.sh
     ```

---

### Incidencia 2: CRDs de Gateway API no reconocidos
* **Síntoma**: Error `no matches for kind "Gateway" in version "gateway.networking.k8s.io/v1"`.
* **Causa Raíz**: Gateway API no viene preinstalado en Kubernetes.
* **Solución**:
  ```bash
  kubectl apply --server-side=true -f https://github.com/kubernetes-sigs/gateway-api/releases/download/v1.6.2/standard-install.yaml
  ```

---

### Incidencia 3: Fallo en la Terminación TLS (Escenario E07)
* **Síntoma**: `curl: (35) OpenSSL SSL_connect: Connection reset by peer`.
* **Causa Raíz**: Falta el Secret `gateway-tls` en el namespace `gateway-lab`.
* **Solución**:
  ```bash
  scripts/crear-certificado.sh
  ```

---

### Incidencia 4: Conflicto entre `kube-proxy` y Cilium eBPF
* **Síntoma**: Warning de conflicto de reglas con iptables o agente en bucle.
* **Solución**: Iniciar Minikube con `--network-plugin=cni --memory=4096 --cpus=2`.

---

### Incidencia 5: Reescritura de URL (E05) devuelve 404
* **Causa**: Mala sintaxis en `ReplacePrefixMatch`.
* **Solución**: Garantizar que el prefijo `/api` se sustituya por `/` en `e05-rewrite.yaml`.

---

### Incidencia 6: Error `namespaces "cilium-secrets" not found` durante la instalación
* **Síntoma**:
  Al ejecutar `cilium install -f values.yaml`, el instalador falla con:
  ```text
  Error: Unable to install Cilium: namespaces "cilium-secrets" not found
  ```
* **Causa Raíz**:
  En `cilium/instalacion/values.yaml` se configuró `gatewayAPI.secretsNamespace.create: false`. Cilium asume que si la creación está deshabilitada, el administrador ya creó manualmente el namespace `cilium-secrets`. Al no encontrarlo, aborta la instalación.
* **Solución**:
  Eliminar la sección `secretsNamespace` de `values.yaml` o definir `create: true`. De este modo Cilium utiliza el namespace local donde reside el Gateway (`gateway-lab`) sin requerir namespaces auxiliares.

---

### Incidencia 7: Error `release name check failed: cannot reuse a name that is still in use`
* **Síntoma**:
  Al reintentar la instalación con `cilium/instalacion/instalar-cilium.sh`, el CLI responde:
  ```text
  Error: Unable to install Cilium: release name check failed: cannot reuse a name that is still in use
  ```
* **Causa Raíz**:
  Una instalación previa falló a mitad de camino y dejó un Release en estado `failed` en el clúster.
* **Solución**:
  Ejecutar una desinstalación limpia antes de reintentar:
  ```bash
  cilium uninstall
  cilium install --version 1.16.2 -f cilium/instalacion/values.yaml --wait
  ```
  *(El script `instalar-cilium.sh` ha sido actualizado para realizar esta limpieza automáticamente si detecta fallos previos).*

---

### Incidencia 8: `cilium-operator` en CrashLoopBackOff (`no matches for kind "TLSRoute" in version "v1alpha2"`)
* **Síntoma**:
  `cilium-operator` se reinicia continuamente. Al inspeccionar sus logs con `kubectl -n kube-system logs -l io.cilium/app=operator`, se observa:
  ```text
  level=fatal msg="failed to start: failed to create gateway controller: failed to setup reconciler: no matches for kind \"TLSRoute\" in version \"gateway.networking.k8s.io/v1alpha2\"" subsys=cilium-operator-generic
  ```
* **Causa Raíz**:
  Cilium v1.16.2 fue compilado para reconciliar `TLSRoute` bajo la versión de API `v1alpha2`. Sin embargo, en **Gateway API v1.6.2 (Standard)**, `TLSRoute` fue promovido a `v1`, y la versión antigua `v1alpha2` se incluye en el CRD pero con la bandera `served: false`. Al intentar consultar ese endpoint, el API Server rechaza la conexión y el operador colapsa.
* **Solución**:
  Habilitar el servicio de `v1alpha2` en el CRD de `TLSRoute` mediante un parche JSON:
  ```bash
  kubectl patch crd tlsroutes.gateway.networking.k8s.io --type=json -p '[{"op": "replace", "path": "/spec/versions/1/served", "value": true}]'
  kubectl -n kube-system rollout restart deployment cilium-operator
  ```

---

### Incidencia 9: Pods de aplicación no están gestionados por el CNI de Cilium
* **Síntoma**:
  Al ejecutar `kubectl apply -k cilium/manifests/extensiones`, las políticas de Cilium no tienen efecto sobre los pods de `httpbin`, o `cilium endpoint list` muestra que los pods no tienen endpoints BPF asignados.
* **Causa Raíz**:
  Si los pods de `httpbin-v1` y `httpbin-v2` se crearon antes de que el DaemonSet de Cilium estuviese completamente listo, conservan la pila de red anterior o quedan sin registrar en los mapas BPF de Cilium.
* **Solución**:
  Reiniciar los pods para que el nuevo CNI de Cilium les asigne interfaces y mapas eBPF:
  ```bash
  kubectl -n gateway-lab rollout restart deployment httpbin-v1 httpbin-v2
  ```

---

### Incidencia 10: Bloqueo de Peticiones del Gateway por Identidad de Red en Capa 7
* **Síntoma**:
  Al aplicar la extensión `CiliumNetworkPolicy`, incluso peticiones legítimas como `GET /get` reciben `status=000` (timeout) o son rechazadas.
* **Causa Raíz**:
  La regla de red usaba `fromEndpoints: - matchLabels: io.kubernetes.pod.namespace: gateway-lab`. Sin embargo, en Cilium, el proxy de Gateway API (Envoy) opera como un componente del sistema y viaja con la identidad de red reservada **`reserved:ingress`**, no como un pod del namespace `gateway-lab`.
* **Solución**:
  Utilizar `fromEntities` en la política:
  ```yaml
  ingress:
    - fromEntities:
        - ingress
        - cluster
        - host
      toPorts:
        - ports:
            - port: "8080"
              protocol: TCP
          rules:
            http:
              - method: GET
                path: "/get"
  ```

---

## Kit de Herramientas de Diagnóstico de Cilium (Toolkit)

1. **Estado integral de Cilium y Envoy**:
   ```bash
   cilium status
   ```
2. **Inspección de pods del CNI y Operador**:
   ```bash
   kubectl -n kube-system get pods -l k8s-app=cilium
   kubectl -n kube-system logs -l io.cilium/app=operator --tail=50
   ```
3. **Monitoreo de tráfico eBPF en tiempo real**:
   ```bash
   cilium monitor -t l7
   ```
4. **Inspección de endpoints gestionados por eBPF**:
   ```bash
   kubectl -n kube-system exec $(kubectl -n kube-system get pod -l k8s-app=cilium -o jsonpath='{.items[0].metadata.name}') -- cilium endpoint list
   ```
5. **Verificación de condiciones del Gateway**:
   ```bash
   kubectl -n gateway-lab get gateway gateway -o yaml | grep -A 15 conditions:
   ```
