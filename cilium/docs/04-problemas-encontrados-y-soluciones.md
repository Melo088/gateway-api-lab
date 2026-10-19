# 04. Problemas Encontrados y Soluciones (Guía de Troubleshooting)

Esta guía documenta los problemas, advertencias y comportamientos anómalos más comunes al desplegar **Cilium Gateway API**, junto con su causa raíz, comandos de diagnóstico y solución paso a paso.

---

## Matriz Resumen de Incidencias

| # | Síntoma / Error | Causa Raíz | Nivel de Severidad | Solución Rápida |
|---|---|---|---|---|
| **1** | Gateway en `PROGRAMMED: False` y Service en `<pending>` | Minikube no asigna IP externa a Services `LoadBalancer` sin túnel activo | Alta | Iniciar `minikube tunnel` o usar `port-forward` |
| **2** | Error `no matches for kind "Gateway"` al aplicar kustomize | Los CRDs oficiales de Gateway API no fueron instalados | Crítica | Aplicar `standard-install.yaml` v1.6.2 |
| **3** | Handshake TLS falla en E07 (`curl: (35) error...`) | Secret `gateway-tls` ausente en el namespace `gateway-lab` | Alta | Ejecutar `scripts/crear-certificado.sh` |
| **4** | Cilium Agent en `CrashLoopBackOff` o `Error` | Conflicto con `kube-proxy` existente o cgroups v2 no montados | Crítica | Iniciar Minikube con `--network-plugin=cni` |
| **5** | E05 (Rewrite) devuelve `404 Not Found` | Reemplazo de prefijo desalineado con las rutas de `httpbin` | Media | Verificar `ReplacePrefixMatch: /` en `e05-rewrite.yaml` |

---

## Diagnóstico Detallado y Solución

### Incidencia 1: El Gateway no obtiene dirección IP externa (`<pending>`)

* **Síntoma**:
  Al ejecutar `kubectl -n gateway-lab get gateway gateway`, la columna `PROGRAMMED` muestra `False` y la columna `ADDRESSES` está vacía.
* **Causa Raíz**:
  En clústeres locales (Minikube / kind), Kubernetes no cuenta con un proveedor de nube (cloud-provider) que asigne una IP pública a los servicios de tipo `LoadBalancer`. El operador de Cilium crea el Service `cilium-gateway-gateway`, pero queda a la espera de que el clúster le suministre una `EXTERNAL-IP`.
* **Comandos de Diagnóstico**:
  ```bash
  kubectl -n gateway-lab get svc
  kubectl -n gateway-lab describe gateway gateway
  ```
  En los eventos del Gateway se observará: `Waiting for Service LoadBalancer external IP`.
* **Solución**:
  1. **Opción A (Recomendada con Minikube)**: Abrir una terminal independiente y ejecutar:
     ```bash
     minikube tunnel
     ```
     En cuestión de 5 segundos, Minikube asignará una IP (ej. `10.96.x.x` o `127.0.0.1`) al servicio y el Gateway pasará a `PROGRAMMED: True`.
  2. **Opción B (Acceso alternativo con port-forward)**:
     Si el túnel no es viable, reenviar los puertos localmente:
     ```bash
     kubectl -n gateway-lab port-forward svc/cilium-gateway-gateway 8080:80 8443:443 &
     GATEWAY_ADDRESS=127.0.0.1 HTTP_PORT=8080 HTTPS_PORT=8443 scripts/verificar.sh
     ```

---

### Incidencia 2: CRDs de Gateway API no reconocidos por el API Server

* **Síntoma**:
  Al ejecutar `kubectl apply -k cilium/manifests`, el comando falla con:
  ```text
  error: resource mapping not found for name: "gateway" namespace: "gateway-lab" 
  from "cilium/manifests": no matches for kind "Gateway" in version "gateway.networking.k8s.io/v1"
  ```
* **Causa Raíz**:
  Gateway API no viene preinstalado en Kubernetes vanilla. Debe instalarse antes de arrancar los controladores y overlays.
* **Solución**:
  Instalar los CRDs oficiales en su versión estable con Server-Side Apply:
  ```bash
  kubectl apply --server-side=true -f https://github.com/kubernetes-sigs/gateway-api/releases/download/v1.6.2/standard-install.yaml
  ```
  Verificar que los CRDs existen:
  ```bash
  kubectl get crd | grep gateway.networking.k8s.io
  ```

---

### Incidencia 3: Fallo en la Terminación TLS (Escenario E07)

* **Síntoma**:
  Al probar `https://tls.lab.local/get`, curl arroja:
  `curl: (35) OpenSSL SSL_connect: Connection reset by peer` o el listener HTTPS no se programa.
* **Causa Raíz**:
  El listener HTTPS en `comun/base/gateway.yaml` busca un Secret de tipo `kubernetes.io/tls` llamado `gateway-tls` en el namespace `gateway-lab`. Si el secret no existe, Cilium no puede inicializar el contexto SSL en Envoy.
* **Comandos de Diagnóstico**:
  ```bash
  kubectl -n gateway-lab get secret gateway-tls
  kubectl -n gateway-lab describe gateway gateway
  ```
* **Solución**:
  Generar el certificado autofirmado con SAN `*.lab.local`:
  ```bash
  scripts/crear-certificado.sh
  ```
  Reiniciar o esperar a que Cilium reconcilie el Gateway (toma ~3 segundos).

---

### Incidencia 4: Conflicto entre `kube-proxy` y Cilium eBPF

* **Síntoma**:
  El agente de Cilium (`cilium-agent`) entra en estado de error o reporta warnings severos sobre colisiones de enrutamiento con iptables.
* **Causa Raíz**:
  Se intentó activar `kubeProxyReplacement=true` en un clúster donde `kube-proxy` sigue activo e interceptando paquetes en las cadenas `KUBE-SERVICES`.
* **Solución**:
  Para clústeres Minikube limpios, inicializar siempre con:
  ```bash
  minikube start --network-plugin=cni --memory=4096 --cpus=2
  ```
  Si `kube-proxy` ya existía, se puede eliminar su DaemonSet:
  ```bash
  kubectl -n kube-system delete daemonset kube-proxy
  ```

---

## Kit de Herramientas de Diagnóstico de Cilium (Toolkit)

Cuando ocurra un comportamiento inesperado, utiliza esta secuencia de comandos para inspeccionar el estado profundo de la red:

1. **Estado integral de Cilium y Envoy**:
   ```bash
   cilium status
   ```
2. **Monitoreo de tráfico eBPF en tiempo real**:
   ```bash
   cilium monitor -t l7
   ```
   *Muestra cada petición HTTP procesada por el proxy Envoy en vivo.*
3. **Inspección de la tabla de balanceo eBPF en el Kernel**:
   ```bash
   cilium bpf lb list
   ```
   *Muestra las IPs virtuales (VIPs) y los backends reales mapeados en las tablas BPF.*
4. **Verificación de condiciones del Gateway**:
   ```bash
   kubectl -n gateway-lab get gateway gateway -o yaml | grep -A 15 conditions:
   ```
