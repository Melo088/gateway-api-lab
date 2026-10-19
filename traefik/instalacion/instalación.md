# Instalación y configuración de Traefik como implementación de Gateway API

## 1. Introducción

Este documento registra el procedimiento técnico de instalación, configuración y verificación de Traefik v3 como implementación de Kubernetes Gateway API en un clúster local gestionado con Minikube. El procedimiento forma parte del repositorio `gateway-api-lab` y se desarrolla exclusivamente en la carpeta `traefik/`, sobre la rama `equipo/traefik`.

Gateway API es el sucesor del recurso `Ingress`. Define un modelo desacoplado en tres recursos principales:

| Recurso | Ámbito | Función |
|---|---|---|
| `GatewayClass` | Clúster | Declara el controlador que implementa los Gateways. |
| `Gateway` | Namespace | Define los listeners: puertos, protocolos, hostnames y TLS. |
| `HTTPRoute` | Namespace | Define las reglas de enrutamiento hacia los Services. |

### 1.1 Componentes utilizados

| Componente | Función en el laboratorio |
|---|---|
| Minikube | Provee un clúster Kubernetes de un solo nodo en la máquina local. |
| kubectl | Cliente de línea de comandos para operar el clúster. Incluye Kustomize mediante la opción `-k`. |
| Kustomize | Permite definir un overlay sobre los manifiestos comunes del repositorio sin modificarlos. |
| Traefik v3 | Proxy inverso que actúa como controlador de Gateway API. |
| Gateway API | Conjunto de CRDs del grupo `gateway.networking.k8s.io`. Versión utilizada: v1.6.2. |

### 1.2 Estructura de trabajo

```text
traefik/
├── README.md          Documentación según plantillas/PLANTILLA-implementacion.md
├── instalacion/       Este documento y los manifiestos de Traefik (01 a 04)
├── manifests/         Overlay kustomize sobre comun/
└── evidencias/        Capturas, salidas de comandos y diagramas
```

Todos los comandos de este documento se ejecutan desde la raíz del repositorio, salvo que se indique lo contrario.

---

## 2. Requisitos y verificación de herramientas

### 2.1 Versiones de las herramientas

```bash
kubectl version --client
```

Muestra la versión del cliente `kubectl`.

```bash
docker version
```

Confirma que el runtime de contenedores utilizado por Minikube está disponible y en ejecución.

```bash
minikube version
```

Muestra la versión de Minikube instalada.

### 2.2 Requisito de versión de Kubernetes

El repositorio establece Kubernetes 1.31 o superior como requisito para los CRDs de Gateway API v1.6, cuyas reglas de validación CEL dependen de funcionalidades presentes desde esa versión. La versión del servidor se consulta con:

```bash
kubectl version
```

La salida incluye `Client Version` y `Server Version`. El valor de `Server Version` debe ser 1.31 o superior.

### 2.3 Compatibilidad entre Traefik y Gateway API

Cada versión de Traefik soporta una versión determinada de la especificación de Gateway API. La versión soportada por la versión de Traefik instalada debe consultarse en la documentación oficial del proveedor Kubernetes Gateway de Traefik (sección Referencias) y compararse con la versión de los CRDs instalados (v1.6.2).

---

## 3. Preparación del repositorio

### 3.1 Clonación y selección de rama

```bash
git clone https://github.com/Melo088/gateway-api-lab.git
cd gateway-api-lab
git switch equipo/traefik
```

Descarga el repositorio y cambia a la rama asignada a la implementación de Traefik. La rama `main` está protegida y solo recibe cambios mediante Pull Request.

### 3.2 Verificación de la rama activa

```bash
git branch --show-current
```

La salida debe ser `equipo/traefik`.

---

## 4. Preparación del entorno con Minikube

Minikube crea un clúster Kubernetes de un solo nodo sobre la máquina local. El nodo ejecuta el plano de control y las cargas de trabajo. El driver `docker` ejecuta el nodo como un contenedor.

### 4.1 Inicio del clúster

```bash
minikube start --driver=docker
```

Crea e inicia el nodo del clúster utilizando Docker como driver y configura el contexto de `kubectl` para apuntar a él.

### 4.2 Verificación del estado del clúster

```bash
minikube status
```
![Estado de Minikube](../evidencias/minikube-status.png)

Los componentes `host`, `kubelet` y `apiserver` deben estar en estado `Running`, y `kubeconfig` en estado `Configured`.

```bash
kubectl config current-context
```

Muestra el contexto activo de `kubectl`. El valor esperado es `minikube`.

```bash
kubectl cluster-info
```

Muestra la dirección del servidor de API y de los servicios principales del clúster.

```bash
kubectl get nodes -o wide
```

![Nodos de Kubernetes - parte 1](../evidencias/kubectl-get-nodes-wide-1.png)
![Nodos de Kubernetes - parte 2](../evidencias/kubectl-get-nodes-wide-2.png)

El nodo `minikube` debe aparecer en estado `Ready`. La columna `VERSION` indica la versión de Kubernetes en ejecución.

### 4.3 Túnel de red para Services de tipo LoadBalancer

En un entorno local, los Services de tipo `LoadBalancer` no reciben una dirección externa de un proveedor de nube. Minikube resuelve esto con un túnel de red:

```bash
minikube tunnel
```
![Estado del túnel de Minikube](../evidencias/minikube-tunnel-status.png)

El comando se ejecuta en una terminal dedicada y debe permanecer activo mientras se utilicen los Services de tipo `LoadBalancer`. Puede solicitar credenciales de administrador para enlazar puertos privilegiados (80 y 443). En Windows se ejecuta desde una terminal con privilegios de administrador. Con el driver `docker`, la dirección externa asignada suele ser `127.0.0.1`.

---

## 5. Instalación de los CRDs de Gateway API

Kubernetes no incluye de forma nativa los CRDs de Gateway API. Deben instalarse antes de iniciar cualquier controlador. Se utiliza el canal Standard en la versión v1.6.2, la misma que documenta el repositorio.

### 5.1 Aplicación de los CRDs

```bash
kubectl apply --server-side=true -f https://github.com/kubernetes-sigs/gateway-api/releases/download/v1.6.2/standard-install.yaml
```

Registra en el servidor de API los recursos del canal Standard: `GatewayClass`, `Gateway`, `HTTPRoute`, `GRPCRoute`, `ReferenceGrant`, entre otros. La opción `--server-side=true` evita superar el límite de tamaño de la anotación `last-applied-configuration` que genera la aplicación del lado del cliente.

### 5.2 Verificación de los CRDs

```bash
kubectl get crd | grep gateway.networking.k8s.io
```
![Listado de CRDs de Gateway API](../evidencias/gateway-api-crds-list.png)

Deben listarse los CRDs del grupo `gateway.networking.k8s.io`.

```bash
kubectl get crd gateways.gateway.networking.k8s.io -o jsonpath='{.metadata.annotations.gateway\.networking\.k8s\.io/bundle-version}{"\n"}'
```

Muestra la versión del conjunto de CRDs instalado. El valor esperado es `v1.6.2`.

```bash
kubectl get gatewayclass
```

La lista debe estar vacía, porque aún no hay un controlador instalado.

---

## 6. Instalación del controlador Traefik

Traefik actúa como plano de datos (proxy inverso) y como plano de control, ya que observa los recursos de Gateway API y configura el enrutamiento.

La instalación es manual: cada recurso que Traefik necesita está en un archivo de `traefik/instalacion/`. `kubectl apply -f` sobre la carpeta los aplica en orden alfabético, por eso llevan prefijo numérico (el namespace debe existir antes que el resto).

### 6.1 Namespace (`01-namespace.yaml`)

```yaml
apiVersion: v1
kind: Namespace
metadata:
  name: traefik
```

Aísla los componentes del controlador del resto de las aplicaciones del clúster.

### 6.2 Identidad y permisos (`02-rbac.yaml`)

| Recurso | Función |
|---|---|
| `ServiceAccount` `traefik` | Identidad con la que el pod se autentica ante el API Server. |
| `ClusterRole` `traefik` | Lectura (`get`, `list`, `watch`) de Services, Secrets, ConfigMaps, EndpointSlices, Namespaces y de los recursos de Gateway API (`gatewayclasses`, `gateways`, `httproutes`, `grpcroutes`, `tcproutes`, `tlsroutes`, `referencegrants`, `backendtlspolicies`). Escritura (`update`) solo sobre sus subrecursos `status`. |
| `ClusterRoleBinding` `traefik` | Asocia el ClusterRole al ServiceAccount. |

Sin estos permisos el proveedor no puede observar los recursos ni escribir las condiciones `Accepted` y `Programmed`.

### 6.3 Deployment (`03-deployment.yaml`)

La configuración estática de Traefik se pasa como argumentos del contenedor:

| Argumento | Descripción |
|---|---|
| `--entryPoints.web.address=:8000/tcp` | Entrypoint HTTP. Los listeners del Gateway deben usar este puerto (sección 7). |
| `--entryPoints.websecure.address=:8443/tcp` y `--entryPoints.websecure.http.tls=true` | Entrypoint HTTPS con terminación TLS. |
| `--entryPoints.traefik.address=:8080/tcp` y `--ping=true` | Entrypoint interno con el endpoint `/ping` que usan las probes de readiness y liveness. |
| `--providers.kubernetesgateway` | Habilita el proveedor que procesa los recursos de Gateway API. |
| `--providers.kubernetesgateway.statusaddress.service.name` y `.namespace` | Service cuya dirección externa se publica en `status.addresses` del Gateway. El script de verificación utiliza ese valor. |

El contenedor usa la imagen `docker.io/traefik:v3.7.14`, se ejecuta como usuario no root (65532) y con sistema de archivos de solo lectura.

### 6.4 Service (`04-service.yaml`)

Service de tipo `LoadBalancer` que expone los puertos 80 y 443 y los redirige a los entrypoints `web` (8000) y `websecure` (8443) del pod. La dirección externa la asigna `minikube tunnel`.

### 6.5 Aplicación y verificación

```bash
kubectl apply -f traefik/instalacion/
```

```text
namespace/traefik created
serviceaccount/traefik created
clusterrole.rbac.authorization.k8s.io/traefik created
clusterrolebinding.rbac.authorization.k8s.io/traefik created
deployment.apps/traefik created
service/traefik created
```

```bash
kubectl -n traefik rollout status deployment/traefik
kubectl -n traefik get pods -l app.kubernetes.io/name=traefik
```

El pod de Traefik debe estar en estado `Running` y con `READY 1/1`.

```bash
kubectl -n traefik get svc traefik
```

El Service debe ser de tipo `LoadBalancer` y mostrar una dirección en la columna `EXTERNAL-IP`. Si aparece `<pending>`, verificar que `minikube tunnel` esté activo.

La `GatewayClass` `traefik` no la crea el controlador: forma parte del overlay (sección 7) y se verifica después de aplicarlo.

Salida completa de la verificación: [`../evidencias/instalacion-manual.txt`](../evidencias/instalacion-manual.txt).

### 6.6 Registro de versiones utilizadas

| Componente | Comando | Valor |
|---|---|---|
| Gateway API (CRDs) | Sección 5.2 | v1.6.2 |
| Kubernetes (servidor) | `kubectl version` | v1.37.0  |
| Minikube | `minikube version` | v1.39.0 |
| Traefik | `kubectl -n traefik get deploy traefik -o wide` | `docker.io/traefik:v3.7.14` |

La instalación manual se verificó además en un clúster limpio con Minikube v1.38.1 y Kubernetes v1.35.1 (7/7 escenarios en `PASS`, [`../evidencias/instalacion-manual.txt`](../evidencias/instalacion-manual.txt)).

---

## 7. Overlay de Kustomize

El Gateway definido en `comun/base/gateway.yaml` se declara con `gatewayClassName: sin-definir` y dos listeners:

| Listener | Protocolo | Puerto | Hostname |
|---|---|---|---|
| `http` | HTTP | 80 | `*.lab.local` |
| `https` | HTTPS | 443 | `*.lab.local` |

Traefik solo acepta un listener si su puerto coincide con el de un entrypoint del pod. Los entrypoints escuchan en los puertos 8000 (`web`) y 8443 (`websecure`), mientras que el Service expone los puertos 80 y 443. Un listener en el puerto 80 provoca que el Gateway sea rechazado con el mensaje `no matching entryPoint for port 80`. Por esta razón el overlay reemplaza, además de `gatewayClassName`, los puertos de los listeners. La documentación `docs/04-escenarios.md` del repositorio prevé este ajuste para los controladores que lo exigen.

### 7.1 Archivo `traefik/manifests/kustomization.yaml`

```yaml
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization
resources:
  - ../../comun
  - gatewayclass.yaml
patches:
  - target:
      kind: Gateway
      name: gateway
    patch: |-
      - op: replace
        path: /spec/gatewayClassName
        value: traefik
      - op: replace
        path: /spec/listeners/0/port
        value: 8000
      - op: replace
        path: /spec/listeners/1/port
        value: 8443
```

| Recurso u operación | Efecto |
|---|---|
| `gatewayclass.yaml` | Declara la `GatewayClass` `traefik` con el controlador `traefik.io/gateway-controller`. |
| `/spec/gatewayClassName` | Asocia el Gateway a la `GatewayClass` `traefik`. |
| `/spec/listeners/0/port` | Cambia el listener `http` del puerto 80 al 8000. |
| `/spec/listeners/1/port` | Cambia el listener `https` del puerto 443 al 8443. |

Los puertos externos no cambian: el Service sigue exponiendo 80 y 443 y los redirige a 8000 y 8443 del pod.

### 7.2 Previsualización del resultado

```bash
kubectl kustomize traefik/manifests | grep -nE 'gatewayClassName|^ +port: (8000|8443|80|443)$'
```
![Previsualización del overlay Kustomize](../evidencias/kustomize-preview-gateway-ports.png)
Debe mostrarse `gatewayClassName: traefik` y los puertos 8000 y 8443 en los listeners.

---

## 8. Certificado TLS

El listener `https` requiere el Secret `gateway-tls` en el namespace `gateway-lab`.

### 8.1 Revisión del script

```bash
cat scripts/crear-certificado.sh
```
![Contenido del script crear-certificado.sh](../evidencias/script-crear-certificado-contenido.png)
Permite verificar las herramientas que requiere el script y los recursos que crea. Los scripts `.sh` requieren un intérprete `bash`; en Windows se ejecutan desde WSL o Git Bash.

### 8.2 Ejecución

```bash
scripts/crear-certificado.sh
```
![Ejecución del script crear-certificado.sh](../evidencias/script-crear-certificado-ejecucion.png)
Genera un certificado autofirmado para `*.lab.local` y crea con él el Secret `gateway-tls`.

### 8.3 Verificación

```bash
kubectl -n gateway-lab get secret gateway-tls
```
![Secret TLS verificado](../evidencias/secret-gateway-tls-verificado.png)
El Secret debe existir con tipo `kubernetes.io/tls`.

---

## 9. Aplicación de los manifiestos del laboratorio

### 9.1 Aplicación

```bash
kubectl apply -k traefik/manifests
```
![Aplicación de manifiestos con Kustomize](../evidencias/manifests-traefik-apply.png)
Crea el namespace `gateway-lab`, los backends `httpbin-v1` y `httpbin-v2` con sus Services, el Gateway y las siete HTTPRoute de los escenarios E01 a E07.

### 9.2 Verificación de los backends

```bash
kubectl -n gateway-lab get pods
```
![Pods de httpbin en ejecución](../evidencias/httpbin-pods-running.png)
Los pods `httpbin-v1` y `httpbin-v2` deben estar en estado `Running` y `READY 1/1`.

```bash
kubectl -n gateway-lab wait --for=condition=Available deployment --all --timeout=120s
```
![Deployments de httpbin disponibles](../evidencias/httpbin-deployments-available.png)
Espera a que ambos Deployments estén disponibles.

```bash
kubectl -n gateway-lab get svc
```
![Services de httpbin](../evidencias/httpbin-services-clusterip.png)
Deben existir los Services `httpbin-v1` y `httpbin-v2` en el puerto 8080.

### 9.3 Verificación del Gateway

```bash
kubectl -n gateway-lab get gateway gateway
```
![Estado programado del Gateway](../evidencias/gateway-status-programmed.png)
La columna `CLASS` debe ser `traefik`, `PROGRAMMED` debe ser `True` y `ADDRESS` debe mostrar una dirección.

```bash
kubectl -n gateway-lab describe gateway gateway
```
![Condiciones generales del Gateway](../evidencias/gateway-describe-status-conditions.png)
![Condiciones del listener HTTP](../evidencias/gateway-describe-listener-http.png)
![Condiciones del listener HTTPS](../evidencias/gateway-describe-listener-https.png)
En la sección `Status` deben aparecer las condiciones `Accepted` y `Programmed` en `True`, y cada listener (`http` y `https`) debe tener `Accepted`, `Programmed` y `ResolvedRefs` en `True`.

### 9.4 Verificación de las rutas

```bash
kubectl -n gateway-lab get httproute
```
![Listado de HTTPRoutes](../evidencias/httproute-escenarios-list.png)
Deben listarse las siete rutas `e01-enrutamiento` a `e07-tls`.

```bash
kubectl -n gateway-lab get httproute -o custom-columns='NAME:.metadata.name,ACCEPTED:.status.parents[0].conditions[?(@.type=="Accepted")].status,RESOLVEDREFS:.status.parents[0].conditions[?(@.type=="ResolvedRefs")].status'
```

Todas las rutas deben mostrar `True` en ambas columnas.

---

## 10. Ejecución de los escenarios

### 10.1 Dirección de acceso al Gateway

```bash
kubectl -n gateway-lab get gateway gateway -o jsonpath='{.status.addresses[0].value}{"\n"}'
```

Muestra la dirección que el script de verificación utiliza como destino. Con `minikube tunnel` activo y el driver `docker`, el valor suele ser `127.0.0.1`.

### 10.2 Script de verificación

```bash
scripts/verificar.sh
```
![Verificación exitosa de los 7 escenarios](../evidencias/verificar-escenarios-pass.png)
Envía peticiones HTTP y HTTPS a los siete escenarios mediante `curl --connect-to`, por lo que no requiere entradas en `/etc/hosts` ni DNS. Reporta `PASS` o `FAIL` por cada escenario.

### 10.3 Resultados esperados

| ID | Hostname | Funcionalidad | Resultado esperado |
|---|---|---|---|
| E01 | `enrutamiento.lab.local` | Enrutamiento por hostname y path | 200 en `GET /get` |
| E02 | `match.lab.local` | Matching por header `x-version: v2` | `httpbin-v2` con el header, `httpbin-v1` sin él |
| E03 | `pesos.lab.local` | Distribución 80/20 | Entre 8 y 35 respuestas de `httpbin-v2` en 100 peticiones |
| E04 | `headers.lab.local` | Modificación de headers de petición y respuesta | `x-gateway-lab` en la petición recibida y en la respuesta |
| E05 | `rewrite.lab.local` | Reescritura de path `/api/<ruta>` a `/<ruta>` | 200 en `GET /api/status/200` |
| E06 | `redirect.lab.local` | Redirección HTTP a HTTPS | 301 con `Location: https://redirect.lab.local/...` |
| E07 | `tls.lab.local` | Terminación TLS en el Gateway | 200 en `GET https://.../get` |

E04 y E05 corresponden a funcionalidades de nivel Extended. Si alguna no está implementada, el resultado se documenta junto con la alternativa propia del controlador, si existe.

### 10.4 Acceso mediante port-forward

Si el Gateway no obtiene dirección, el acceso alternativo es un reenvío de puertos hacia el Service de Traefik:

```bash
kubectl -n traefik port-forward svc/traefik 8080:80 8443:443
```

En otra terminal:

```bash
GATEWAY_ADDRESS=127.0.0.1 HTTP_PORT=8080 HTTPS_PORT=8443 scripts/verificar.sh
```

### 10.5 Prueba manual de un escenario

```bash
curl -i --connect-to enrutamiento.lab.local:80:<direccion>:80 http://enrutamiento.lab.local/get
```

Prueba E01 sin depender del script. `<direccion>` es el valor obtenido en la sección 10.1.

```bash
curl -ik --connect-to tls.lab.local:443:<direccion>:443 https://tls.lab.local/get
```

Prueba E07. La opción `-k` omite la validación del certificado autofirmado.

---

## 11. Resolución de problemas

### 11.1 Gateway rechazado: `no matching entryPoint`

Síntoma: el Gateway no muestra `Accepted` o `Programmed` en `True`.

Diagnóstico:

```bash
kubectl -n gateway-lab describe gateway gateway
kubectl -n traefik logs deployment/traefik
```

Causa: el puerto de un listener no coincide con el de un entrypoint de Traefik.

Solución: verificar que el overlay reemplace los puertos de los listeners por 8000 y 8443 (sección 7) y que `--entryPoints.web.address` y `--entryPoints.websecure.address` en `03-deployment.yaml` usen esos mismos puertos.

### 11.2 Service con `EXTERNAL-IP` en `<pending>`

Síntoma: `kubectl -n traefik get svc traefik` muestra `<pending>`.

Causa: `minikube tunnel` no está en ejecución.

Solución: iniciar `minikube tunnel` en una terminal dedicada. Como alternativa, utilizar el acceso por port-forward de la sección 10.4.

### 11.3 La GatewayClass no existe o no está aceptada

Síntoma: `kubectl get gatewayclass` no lista `traefik`, o la columna `ACCEPTED` muestra `Unknown`.

Causa: la `GatewayClass` se crea con el overlay (`traefik/manifests/gatewayclass.yaml`), no con la instalación. `Unknown` indica que el pod de Traefik no está procesando recursos.

Solución: aplicar `kubectl apply -k traefik/manifests` y revisar `kubectl -n traefik logs deployment/traefik`. Si `kube-proxy` está en `CrashLoopBackOff` con `too many open files` (frecuente con varios clústeres minikube en el mismo host), el pod no alcanza el API Server: aumentar los límites de inotify del host con `sudo sysctl fs.inotify.max_user_instances=512 fs.inotify.max_user_watches=524288` y reiniciar los pods de `kube-proxy`.

### 11.4 Error al crear el Secret por namespace inexistente

Síntoma: `scripts/crear-certificado.sh` falla porque el namespace `gateway-lab` no existe.

Solución: aplicar primero `kubectl apply -k traefik/manifests`, ejecutar después el script y verificar el Secret con el comando de la sección 8.3.

### 11.5 Rutas sin aceptar

Síntoma: una HTTPRoute no muestra `Accepted` en `True`.

Diagnóstico:

```bash
kubectl -n gateway-lab describe httproute <nombre>
```

Causa habitual: el Gateway asociado no está programado (secciones 11.1 y 11.3) o el Secret `gateway-tls` no existe, lo que afecta al listener `https` y a la ruta E07.

---

## 12. Limpieza

```bash
kubectl delete -k traefik/manifests
```

Elimina el namespace `gateway-lab` y todos los recursos del laboratorio.

```bash
kubectl delete -f traefik/instalacion/
```

Elimina el namespace `traefik`, el RBAC, el Deployment y el Service de Traefik. La `GatewayClass` se elimina con el overlay en el paso anterior.

```bash
kubectl delete -f https://github.com/kubernetes-sigs/gateway-api/releases/download/v1.6.2/standard-install.yaml
```

Elimina los CRDs de Gateway API. Esta operación borra también todos los recursos de Gateway API existentes en el clúster, por lo que solo debe ejecutarse si ninguna otra implementación los utiliza.

```bash
minikube stop
```

Detiene el clúster conservando su estado. `minikube delete` lo elimina por completo.

---

## 13. Referencias

- Traefik, Kubernetes Gateway API: <https://doc.traefik.io/reference/routing-configuration/kubernetes/gateway-api>
- Opciones del proveedor `kubernetesgateway`: <https://doc.traefik.io/traefik/reference/install-configuration/providers/kubernetes/kubernetes-gateway/>
- Gateway API: <https://gateway-api.sigs.k8s.io/>
- Minikube: <https://minikube.sigs.k8s.io/docs/>
- kubectl: <https://kubernetes.io/docs/reference/kubectl/>
- Kustomize: <https://kubectl.docs.kubernetes.io/references/kustomize/>