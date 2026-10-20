# 04. Problemas Encontrados y Soluciones (Guía de Troubleshooting)

Esta guía documenta los problemas, advertencias y comportamientos anómalos encontrados durante el despliegue de **Cilium Gateway API**, junto con su causa raíz, comandos de diagnóstico y solución paso a paso.

---

## Matriz Resumen de Incidencias

| # | Síntoma / Error | Causa Raíz | Nivel de Severidad | Solución Rápida |
|---|---|---|---|---|
| **1** | Service `cilium-gateway-gateway` en `<pending>` | Minikube no asigna IP externa a Services `LoadBalancer` | Alta | Aplicar el pool de LB IPAM (`instalacion/lb-ipam.yaml`) |
| **2** | Error `no matches for kind "Gateway"` al aplicar kustomize | Los CRDs oficiales de Gateway API no fueron instalados | Crítica | Aplicar `standard-install.yaml` v1.6.2 |
| **3** | Handshake TLS falla en E07 (`curl: (35) error...`) | Secret `gateway-tls` ausente en el namespace `gateway-lab` | Alta | Ejecutar `scripts/crear-certificado.sh` |
| **4** | Cilium Agent en `CrashLoopBackOff` o `Error` | Conflicto con `kube-proxy` existente o cgroups v2 no montados | Crítica | Iniciar Minikube con `--network-plugin=cni --cni=false` y sin `kube-proxy` |
| **5** | E05 (Rewrite) devuelve `404 Not Found` | Reemplazo de prefijo desalineado con las rutas de `httpbin` | Media | Verificar `ReplacePrefixMatch: /` en `e05-rewrite.yaml` |
| **6** | `Error: namespaces "cilium-secrets" not found` al instalar | Directiva `secretsNamespace.create: false` en `cilium.yaml` sin namespace existente | Alta | Omitir `secretsNamespace` o poner `create: true` |
| **7** | `release name check failed: cannot reuse a name that is still in use` | Intento previo de instalación falló a medio camino dejando release rota | Media | Ejecutar `cilium uninstall` antes de reinstalar |
| **8** | `cilium-operator` en CrashLoopBackOff: `no matches for kind "TLSRoute" in version "v1alpha2"` | Gateway API v1.6.2 deshabilita `v1alpha2` (`served: false`), requerido por Cilium 1.16 | Crítica | Usar Cilium 1.20.3, compilado contra Gateway API v1.6 |
| **9** | `CiliumNetworkPolicy` no bloquea o pods no reciben CNI | Los pods de `httpbin` se levantaron antes de que Cilium estuviese listo | Media | Ejecutar `rollout restart` sobre los Deployments |
| **10**| Extensión L7 bloquea al Gateway (`status=000` o timeout) | La política L7 usa `fromEndpoints` y desconoce la identidad `reserved:ingress` | Alta | Usar `fromEntities: [ingress, cluster, host]` |
| **11**| Gateway `Programmed` con IP, pero todas las peticiones expiran | Driver `docker` de minikube: el tráfico marcado por `TPROXY` no llega al socket de Envoy | Crítica | Usar `minikube start --driver=kvm2` |
| **12**| Pods de Cilium en `ImagePullBackOff` en la VM kvm2 | La VM no tiene salida a internet (NAT de libvirt) | Alta | Corregir la red de libvirt o cargar imágenes con `minikube image load` |

---

## Diagnóstico Detallado y Solución

### Incidencia 1: El Gateway no obtiene dirección IP externa (`<pending>`)
* **Síntoma**: `kubectl -n gateway-lab get svc cilium-gateway-gateway` muestra `EXTERNAL-IP <pending>` y el Gateway no tiene dirección en `status.addresses`.
* **Causa Raíz**: Minikube no cuenta con un proveedor de nube que asigne IPs a los Services `LoadBalancer`.
* **Solución**: usar LB IPAM de Cilium. `cilium.yaml` activa `l2announcements` y `externalIPs`, y `lb-ipam.yaml` define el rango (de la subred de `minikube ip`) y la política de anuncio ARP:
  ```bash
  kubectl apply -f cilium/instalacion/lb-ipam.yaml
  kubectl -n gateway-lab get svc cilium-gateway-gateway   # EXTERNAL-IP 192.168.39.200
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
  Al ejecutar `cilium install -f cilium.yaml`, el instalador falla con:
  ```text
  Error: Unable to install Cilium: namespaces "cilium-secrets" not found
  ```
* **Causa Raíz**:
  En `cilium/instalacion/cilium.yaml` se configuró `gatewayAPI.secretsNamespace.create: false`. Cilium asume que si la creación está deshabilitada, el administrador ya creó manualmente el namespace `cilium-secrets`. Al no encontrarlo, aborta la instalación.
* **Solución**:
  Eliminar la sección `secretsNamespace` de `cilium.yaml` o definir `create: true`. De este modo Cilium utiliza el namespace local donde reside el Gateway (`gateway-lab`) sin requerir namespaces auxiliares.

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
  cilium install --version 1.20.3 -f cilium/instalacion/cilium.yaml --wait
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
  Cilium v1.16.2 está compilado contra Gateway API v1.1 y reconcilia `TLSRoute` en `v1alpha2`. En **Gateway API v1.6.2 (Standard)**, `TLSRoute` es `v1` y `v1alpha2` queda con `served: false`, así que el operador no encuentra el recurso y termina.
* **Solución**:
  Usar una versión de Cilium compilada contra Gateway API v1.6: **Cilium 1.20.3** (`sigs.k8s.io/gateway-api v1.6.3` en su `go.mod`).
  ```bash
  cilium install --version 1.20.3 -f cilium/instalacion/cilium.yaml --wait
  ```
  No se parchea el CRD `tlsroutes`: es compartido por todas las implementaciones del laboratorio y reactivar `v1alpha2` altera la API del clúster para los demás controladores.

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

### Incidencia 11: Gateway programado pero sin respuesta con el driver `docker`
* **Síntoma**: el Gateway queda `Programmed=True` con IP de LB IPAM y el ARP resuelve, pero `curl` expira (`000`) contra la IP, el NodePort e incluso desde dentro del nodo.
* **Diagnóstico**:
  ```bash
  kubectl -n kube-system exec ds/cilium -c cilium-agent -- cilium-dbg envoy admin metrics | grep listener_downstream_cx_total
  minikube ssh -- 'sudo iptables-save -c -t mangle | grep TPROXY'
  ```
  La regla `TPROXY` acumula paquetes pero el listener de Envoy registra 0 conexiones. Con `bpf.tproxy=true` las conexiones llegan a Envoy, pero las de Envoy hacia los pods expiran (`upstream_cx_connect_timeout`).
* **Causa Raíz**: en el nodo de minikube con driver `docker` (kernel del host Fedora 7.1, `iptables-nft`), el tráfico redirigido por TPROXY no se entrega al socket transparente de Envoy. Se probaron sin éxito `bpf.tproxy`, `bpf.hostLegacyRouting`, `bpf.masquerade=false` y Envoy embebido.
* **Solución**: usar una VM con kernel propio:
  ```bash
  minikube start --driver=kvm2 --cpus=2 --memory=4096 --network-plugin=cni --cni=false --extra-config=kubeadm.skip-phases=addon/kube-proxy
  ```
  Con kvm2 (kernel 6.6.95) la configuración por defecto funciona: 7/7 escenarios.

---

### Incidencia 12: Imágenes de Cilium sin descargar en la VM kvm2
* **Síntoma**: `cilium`, `cilium-operator` y `cilium-envoy` en `ImagePullBackOff`; desde la VM, `ping 1.1.1.1` no responde.
* **Causa Raíz**: el NAT de la red `default` de libvirt no reenvía tráfico (reglas del firewall del host).
* **Solución**: corregir la red de libvirt, o descargar las imágenes en el host y cargarlas en la VM. Como `docker load` no conserva los digests, se instala con `image.useDigest: false`, `operator.image.useDigest: false` y `envoy.image.useDigest: false`:
  ```bash
  for i in quay.io/cilium/cilium:v1.20.3 quay.io/cilium/operator-generic:v1.20.3 \
           quay.io/cilium/cilium-envoy:v1.38.6-1791537840-00e749f11f69334c625e53fc1ce2fc6c7f34a51f \
           mccutchen/go-httpbin:2.25.0; do
    docker pull "$i" && minikube image load "$i"
  done
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
