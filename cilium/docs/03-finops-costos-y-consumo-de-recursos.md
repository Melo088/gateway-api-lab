# 03. Análisis FinOps: Consumo de Recursos y Optimización de Costos con Cilium

En la ingeniería de plataformas moderna, el marco **FinOps** (Financial Operations) busca alinear las decisiones de arquitectura tecnológica con la eficiencia económica y la rentabilidad del negocio.

Aunque este laboratorio se ejecuta localmente sobre Minikube, evaluar el impacto de costes que tiene Cilium en entornos cloud productivos (AWS, GCP, Azure) es fundamental para justificar su adopción frente a controladores tradicionales.

---

## 1. Perfil de Consumo de Recursos (CPU y Memoria)

Cilium opera con una arquitectura distribuida donde el plano de datos reside en el propio kernel Linux.

### Huella de Recursos por Componente

| Componente | Tipo de Despliegue | Consumo CPU Típico | Consumo RAM Típico | Justificación Técnica |
|---|---|---|---|---|
| `cilium-agent` | DaemonSet (1 pod por nodo) | 100m – 300m vCPU | 256Mi – 512Mi | Compila y carga programas eBPF en los sockets del kernel. Mantiene las tablas de mapas BPF. |
| `cilium-operator` | Deployment (1 o 2 réplicas HA) | 20m – 50m vCPU | 64Mi – 128Mi | Administra el ciclo de vida del clúster, sincroniza IPAM y reconcilia los recursos Gateway. |
| `cilium-envoy` | Embebido en agent o Pod dedicado | 50m – 250m vCPU | 64Mi – 256Mi | Procesa el tráfico HTTP/TLS de capa 7 (E01-E07). Escala según peticiones por segundo (RPS). |

### Comparación con Soluciones Tradicionales
* **Frente a Ingress tradicionales + Service Mesh**: En una arquitectura con Ingress clásico e Istio con sidecars, cada pod de la aplicación carga un contenedor Envoy (consumiendo 50-100MB de RAM por cada pod). Con 200 microservicios, el desperdicio de memoria en sidecars ronda los 15-20 GB. **Cilium centraliza Envoy a nivel de nodo**, ahorrando hasta un **60% de memoria RAM** en clústeres densos.
* **Frente a `iptables`**: En clústeres con más de 5,000 servicios, `kube-proxy` requiere evaluar miles de reglas secuenciales para cada paquete. eBPF utiliza tablas hash BPF en memoria con complejidad de búsqueda **$O(1)$**, liberando entre un **15% y un 25% de ciclos de CPU** que pueden ser aprovechados por las cargas de trabajo de negocio.

---

## 2. Impacto Económico en Proveedores Cloud (AWS, GCP, Azure)

### A. Ahorro por Consolidación de Balanceadores (Modo Compartido vs. Dedicado)
En proveedores de nube pública, cada `Service` de tipo `LoadBalancer` aprovisiona un balanceador gestionado (AWS NLB/ALB, Google Cloud Forwarding Rule, Azure Standard Load Balancer):

* **Costo Base por Balanceador**: Aprox. **\$16.20 - \$18.00 USD / mes** (solo por existir, sin contar consumo de datos).
* **Escenario con 30 Microservicios**:
  * **Enfoque Ingress Antiguo / Balancers Dedicados**: 30 Services `LoadBalancer` = **\$540.00 USD / mes**.
  * **Enfoque Gateway API con Cilium (Modo Compartido)**: 1 único Gateway `LoadBalancer` consolidado con 30 `HTTPRoutes` = **\$18.00 USD / mes**.
  * **Ahorro Directo de FinOps**: **\$522.00 USD / mes** (más de **\$6,200 USD anuales**) únicamente en costos fijos de red perimetral.

```text
Costo Mensual de Balanceadores Cloud (30 Microservicios)
─────────────────────────────────────────────────────────────
Ingress Tradicional (Dedicado)   ████████████████████ $540 USD
Gateway API Cilium (Compartido)  █ $18 USD (96.6% Ahorro)
─────────────────────────────────────────────────────────────
```

### B. Optimización de Ancho de Banda con Direct Server Return (DSR)
Tradicionalmente, el tráfico de respuesta desde los pods vuelve a salir a través del nodo que recibió la petición original (balanceador SNAT), duplicando el tráfico interno entre zonas de disponibilidad (Cross-AZ Traffic), el cual se factura a **\$0.01 por GB** en AWS/GCP.

* Con Cilium **Direct Server Return (DSR)** potenciado por eBPF:
  1. El cliente envía la petición al Gateway.
  2. Cilium enruta el paquete al pod en el nodo B preservando la IP original del cliente.
  3. La respuesta HTTP sale **directamente desde el nodo B hacia Internet**, sin rebotar por el nodo del Gateway.
* **Impacto FinOps**: Reduce los cargos de transferencia de datos en balanceadores de carga hasta en un **50%**, generando ahorros masivos en aplicaciones que sirven contenido pesado (imágenes, video, APIs con respuestas JSON extensas).

---

## 3. Consideraciones para Entornos Locales (Minikube)

Para ejecutar este laboratorio sin saturar la máquina local de desarrollo:

* **Asignación Mínima Recomendada**:
  * **vCPUs**: 2 núcleos.
  * **Memoria RAM**: 4 GB (4096 MB).
  * **Almacenamiento**: 20 GB.
* **Comportamiento en Minikube**:
  * En local no se incurre en facturación monetaria, pero el consumo de RAM/CPU es visible en el host.
  * Al reemplazar `kube-proxy`, Minikube se vuelve notablemente más ágil y responde más rápido ante la creación y eliminación masiva de servicios y rutas.
  * `minikube tunnel` emula el comportamiento de un Cloud Load Balancer asignando una IP virtual de la interfaz de red local (`10.x.x.x` o `127.0.0.1`), permitiendo replicar el 100% de la experiencia productiva a coste cero.
