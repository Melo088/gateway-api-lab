# 01. De Ingress a Gateway API: La Evolución de la Red en Kubernetes con Cilium

## 1. El Declive y Obsolescencia de `Ingress`

El recurso `Ingress` (`networking.k8s.io/v1`) fue el estándar de establecido para exponer servicios HTTP y HTTPS fuera de los clústeres de Kubernetes. Sin embargo, la arquitectura original de Ingress fue concebida en los inicios de Kubernetes y adolece de problemas estructurales que hoy son cuellos de botella críticos:

### A. La Retirada Oficial de `ingress-nginx` (Marzo de 2026)
El controlador histórico `kubernetes/ingress-nginx` anunció su fin de ciclo (*End of Life*) definitivo en marzo de 2026 debido a:
* Acumulación de deuda técnica e incidentes recurrentes de seguridad derivados de directivas de configuración (*snippets*) arbitrarias de NGINX.
* Incompatibilidad del modelo monolítico con los requerimientos modernos de arquitecturas multi-tenant y Zero Trust.
* Decisión del SIG-Network de congelar la API de Ingress para enfocar todos los esfuerzos de innovación en **Gateway API**.

### B. Limitaciones Arquitecturales de Ingress

1. **API Monolítica sin Separación de Responsabilidades**:
   En Ingress, un único manifiesto mezcla:
   * **Infraestructura**: Direcciones IP, puertos, terminación TLS, certificados.
   * **Lógica de Aplicación**: Enrutamiento de URLs, reescritura de cabeceras, servicios de destino.
   Esto obliga a los desarrolladores a tener permisos sobre configuraciones críticas del clúster o al equipo de infraestructura a gestionar cada cambio de ruta.

2. **Proliferación Incontrolada de Annotations Propietarias**:
   Cualquier funcionalidad avanzada (balanceo ponderado canary, reescrituras de path, autenticación, rate limiting) no existía en el esquema tipado de Kubernetes. Cada proveedor inventó sus propias anotaciones:
   * `nginx.ingress.kubernetes.io/rewrite-target`
   * `traefik.ingress.kubernetes.io/router.middlewares`
   * `konghq.com/plugins`
   Esto destruyó la **portabilidad**: un archivo Ingress no funciona de la misma manera si se cambia de controlador.

3. **Sin Soporte Nativo para Protocolos Modernos**:
   Ingress fue diseñado únicamente para HTTP y HTTPS. Protocolos como **gRPC**, **WebSockets seguros**, **TLS Passthrough (SNI)** o tráfico de capa 4 (**TCP/UDP**) requerían soluciones parcheadas o controladores secundarios.

4. **Dependencia de `iptables` y Cuellos de Botella en el Kernel**:
   La mayoría de los controladores Ingress tradicionales dependen de `kube-proxy` y cadenas masivas de `iptables`. A medida que el clúster crece a miles de servicios, la evaluación secuencial de reglas de `iptables` degrada drásticamente la latencia y satura la CPU de los nodos.

---

## 2. Gateway API: El Nuevo Estándar de la CNCF

**Gateway API** (`gateway.networking.k8s.io`, versión **v1.6.2 GA**) es el sucesor formal de Ingress, mantenido por SIG-Network. Sus principios rectores resuelven punto por punto los defectos de Ingress:

### A. Modelo Orientado a Roles
Gateway API desacopla el ciclo de vida del tráfico en tres capas con control de acceso basado en roles (RBAC) independiente:

```text
+-----------------------------+-------------------------------+------------------------------+
| Proveedor de Infraestructura|      Operador del Clúster     |   Desarrollador de la App    |
|       (Infra Provider)      |       (Cluster Operator)      |     (Application Developer)  |
+-----------------------------+-------------------------------+------------------------------+
|        GatewayClass         |            Gateway            |     HTTPRoute / GRPCRoute    |
|   (Registra el controlador  |     (Define puertos 80/443,   |   (Define reglas, matches,   |
|        de red Cilium)       |     listeners y certificados) |    filtros y pesos canary)   |
+-----------------------------+-------------------------------+------------------------------+
```

### B. Portabilidad Verificada y Pruebas de Conformidad
A diferencia de las annotations, los filtros comunes (`RequestHeaderModifier`, `URLRewrite`, `RequestRedirect`) están formalmente tipados en la especificación. La CNCF ejecuta pruebas de conformidad estrictas sobre cada implementación.

### C. Soporte Extensible Multi-Protocolo
Define rutas dedicadas: `HTTPRoute`, `GRPCRoute`, `TLSRoute`, `TCPRoute` y `UDPRoute`.

---

## 3. Tabla Comparativa: Ingress vs. Gateway API con Cilium

| Criterio | Ingress Clásico | Gateway API con Cilium |
|---|---|---|
| **API** | `networking.k8s.io/v1` (Congelada) | `gateway.networking.k8s.io/v1` (v1.6.2 GA, activa) |
| **Separación de Roles** | No (monolítico) | Sí (`GatewayClass`, `Gateway`, `xRoute`) |
| **Mecanismo de Balanceo** | `iptables` / `IPVS` secuencial | **eBPF Socket Layer + BPF Maps (O(1))** |
| **Motor L7 de Datos** | NGINX, HAProxy en userspace | **Envoy embebido de alto rendimiento** |
| **Seguridad de Red** | NetworkPolicy L3/L4 estándar | **CiliumNetworkPolicy con inspección eBPF L7** |
| **Visibilidad de IP Origen**| Requiere `externalTrafficPolicy: Local` | Nativa mediante **TPROXY y eBPF** |
| **Portabilidad de Rutas** | Nula (atada a annotations) | Total (definida por el estándar de la CNCF) |
| **Observabilidad** | Logs de acceso tradicionales | Métricas en tiempo real con **Hubble L7** |

---

## 4. Por qué Cilium es el Controlador Ideal para Gateway API

Cilium no es simplemente "otro controlador Ingress". Cilium es un **CNI nativo de la nube** que opera en el propio kernel Linux mediante eBPF. 

Al adoptar Gateway API:
1. **Unifica la capa de red**: El mismo componente que gestiona el enrutamiento pod-a-pod (East-West) gestiona la entrada al clúster (North-South).
2. **Elimina capas intermedias**: No requiere desplegar un Ingress Controller separado de terceros que añada saltos de red adicionales.
3. **Consistencia de Seguridad Zero Trust**: La misma política declarativa puede regular el tráfico desde el borde exterior hasta el microservicio más profundo.
