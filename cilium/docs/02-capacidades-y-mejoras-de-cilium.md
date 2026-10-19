# 02. Capacidades y Mejoras Arquitecturales de Cilium en Gateway API

El ecosistema de Kubernetes cuenta con múltiples controladores de entrada, pero muchos introducen complejidad innecesaria, problemas de escalabilidad y cuellos de botella al depender de construcciones de red heredadas como `iptables`.

Cilium reimagina el enrutamiento y la exposición de servicios combinando **eBPF (Extended Berkeley Packet Filter)** con un plano de datos **Envoy** integrado y consciente del protocolo.

---

## 1. Modos Flexibles de Balanceador de Carga (Flexible Load Balancer Modes)

Una de las grandes ventajas de Cilium frente a soluciones rígidas es su capacidad de adaptarse a los requisitos de arquitectura mediante dos modos de despliegue para los balanceadores:

```text
       MODO COMPARTIDO (Shared)                        MODO DEDICADO (Dedicated)
+------------------------------------+    +-----------------------------------------------+
|  1 Único Service LoadBalancer      |    |  Service LB 1            Service LB 2         |
|  (1 IP Pública / 1 Listener)       |    |  (App Crítica / Pagos)   (App Pública / Blog) |
|         │                          |    |         │                         │           |
|         ▼                          |    |         ▼                         ▼           |
|  Gateway Compartido (Múltiples     |    |  Gateway Dedicado 1      Gateway Dedicado 2   |
|  HTTPRoutes: App A, App B, App C)  |    |  (Aislamiento Total)     (Aislamiento Total)  |
+------------------------------------+    +-----------------------------------------------+
```

### A. Modo Compartido (*Shared Mode*)
* **Funcionamiento**: Se utiliza un único recurso `Gateway` que aprovisiona un solo Service `LoadBalancer` para atender múltiples recursos `HTTPRoute` de diferentes namespaces o equipos.
* **Beneficio**: Conservación drástica de recursos en nube pública. Reduce costes directos de infraestructura al no tener que pagar por un Cloud Load Balancer (NLB/ALB) para cada servicio individual.
* **Uso en este laboratorio**: Es el modelo implementado en `comun/base/gateway.yaml`, donde un único Gateway atiende los 7 escenarios bajo el comodín `*.lab.local`.

### B. Modo Dedicado (*Dedicated Mode*)
* **Funcionamiento**: Cada aplicación o grupo de servicios recibe un `Gateway` independiente con su propio Service `LoadBalancer` e IP pública dedicada.
* **Beneficio**: Evita colisiones de prefijos de ruta entre equipos autónomos, ofrece aislamiento de rendimiento garantizado y previene que un pico de tráfico en un microservicio afecte a otros.

---

## 2. Visibilidad Total de la IP de Origen (*Seamless Source IP Visibility*)

En los controladores de entrada convencionales, la dirección IP del cliente real que realiza la petición suele perderse debido al Source NAT (SNAT) que realiza `kube-proxy` o el propio balanceador para dirigir el paquete al pod correcto. Para recuperarla, se solía recurrir a soluciones complejas o configurar `externalTrafficPolicy: Local`, lo que genera desbalanceo de tráfico entre nodos.

Cilium resuelve este problema de manera transparente:

### A. Integración con `TPROXY` y eBPF
* Cilium intercepta los paquetes entrantes a nivel de socket utilizando programas eBPF y sockets **TPROXY (Transparent Proxying)**.
* Esto permite reenviar el tráfico al proxy Envoy local sin modificar la tupla IP original de la conexión TCP.

### B. Transparencia en Cabeceras HTTP
* Envoy recibe la conexión con la IP de origen intacta y la inyecta automáticamente en:
  * `X-Forwarded-For`: Lista con la IP pública del cliente real.
  * `X-Envoy-External-Address`: Dirección externa de confianza detectada.
* **Impacto Operativo**: Vital para logging de auditoría, depuración de incidencias, geolocalización de tráfico y aplicación de políticas de seguridad basadas en IP (listas de bloqueo o limitación de tasa por IP) sin parches ni configuraciones exóticas.

---

## 3. Gestión Avanzada de TLS (*Advanced TLS Management*)

Cilium simplifica radicalmente la gestión de conexiones seguras tanto en el perímetro como internamente:

### A. Terminación TLS (*TLS Termination*)
* Implementada en el escenario **E07** (`tls.lab.local`).
* El Gateway descifra el tráfico HTTPS en el puerto 443 utilizando el Secret de Kubernetes (`gateway-tls`) y lo entrega en texto plano de alta velocidad (HTTP) a los pods de aplicación.

### B. TLS Passthrough Dinámico
* A través del recurso `TLSRoute` de Gateway API, Cilium puede inspeccionar el campo **SNI (Server Name Indication)** del protocolo TLS en el handshake sin descifrar el tráfico, reenviando los bytes cifrados directamente al pod destino.
* Esto es ideal para aplicaciones con requerimientos estrictos de cumplimiento normativo (PCI-DSS, HIPAA) donde la clave privada debe residir exclusivamente dentro del contenedor de la aplicación.

### C. Compartición Multi-TLS y Multi-Dominio
* Un único listener HTTPS puede gestionar múltiples certificados para diferentes hostnames simultáneamente, seleccionando el certificado adecuado según el SNI presentado por el cliente.

---

## 4. Seguridad de Red Potenciada por eBPF (*eBPF Powered Network Security*)

A diferencia de los proxies tradicionales que operan aislados de la pila de red, Cilium integra la seguridad directamente en el kernel mediante eBPF:

```text
                                 PETICIÓN ENTRANTE
                                         │
                                         ▼
                      +──────────────────────────────────────+
                      |        CAPA 1: FILTRADO eBPF         |
                      |   (Kernel Linux - L3 / L4 / CIDR)    |
                      +──────────────────────────────────────+
                                         │
                                         ▼
                      +──────────────────────────────────────+
                      |        CAPA 2: MOTOR L7 ENVOY        |
                      |  (HTTP Methods, Paths, Headers, JWT) |
                      +──────────────────────────────────────+
                                         │
                                         ▼
                                   POD DESTINO
```

### A. Seguridad en Doble Capa (Dual-Layer Security)
1. **Filtro de Capa de Red (eBPF en Kernel)**:
   Antes de que un paquete consuma ciclos de CPU en el espacio de usuario, los programas eBPF evalúan reglas de nivel de red (L3/L4), descartando paquetes maliciosos o no autorizados a la máxima velocidad del hardware.
2. **Filtro de Capa de Aplicación (Envoy integrado)**:
   Si el paquete es válido, pasa al motor de políticas de Envoy para inspeccionar métodos HTTP, rutas y cabeceras mediante `CiliumNetworkPolicy`.

### B. Control Granular con `CiliumNetworkPolicy` (CNP)
Como se demuestra en el manifiesto `cilium/manifests/extensiones/x01-l7-policy.yaml`:
* Se puede restringir qué pods pueden recibir peticiones del Gateway.
* Se pueden declarar listas blancas de métodos HTTP (permitir `GET` y bloquear `POST`/`DELETE`).
* Se bloquea cualquier intento de ataque a endpoints no autorizados con una respuesta `403 Forbidden` emitida en el propio borde del clúster.

### C. Observabilidad con Hubble L7
* Cilium cuenta con **Hubble**, su plataforma de observabilidad integrada que permite visualizar mapas de tráfico L7 en tiempo real, latencias P99 de peticiones HTTP, códigos de error HTTP y flujos de red sin necesidad de instrumentar las aplicaciones ni inyectar sidecars invasivos.
