# 03. Análisis FinOps: Consumo de Recursos y Optimización de Costos con Cilium

En la ingeniería de plataformas moderna, el marco **FinOps** (Financial Operations) busca alinear las decisiones de arquitectura tecnológica con la eficiencia económica y la rentabilidad del negocio.

Este laboratorio se ejecuta localmente sobre Minikube y no mide costos ni consumo. Este documento describe de forma cualitativa qué aspectos de la arquitectura de Cilium influyen en el costo en entornos cloud productivos (AWS, GCP, Azure).

---

## 1. Componentes que consumen recursos

Cilium opera con una arquitectura distribuida donde el plano de datos reside en el propio kernel Linux.

| Componente | Tipo de Despliegue | Función |
|---|---|---|
| `cilium-agent` | DaemonSet (1 pod por nodo) | Compila y carga programas eBPF y mantiene los mapas BPF. Su consumo crece con el número de endpoints, Services y políticas. |
| `cilium-operator` | Deployment (1 o 2 réplicas HA) | Sincroniza IPAM y reconcilia los recursos de Gateway API. |
| `cilium-envoy` | DaemonSet (1 pod por nodo) | Procesa el tráfico HTTP/TLS de capa 7 (E01-E07). Su consumo crece con las peticiones por segundo. |

### Comparación con Soluciones Tradicionales
* **Frente a un service mesh con sidecars**: cada pod de la aplicación carga su propio contenedor Envoy, y la memoria total crece con el número de pods. **Cilium usa un Envoy por nodo**, compartido por todos los Gateways y políticas L7 del nodo.
* **Frente a `iptables`**: con muchos Services, `kube-proxy` evalúa cadenas de reglas que crecen linealmente. eBPF usa tablas hash con búsqueda de coste constante, así que el coste por paquete no depende del número de Services.

---

## 2. Factores de costo en proveedores cloud

### A. Consolidación de balanceadores (Gateway compartido)
En proveedores de nube pública, cada `Service` de tipo `LoadBalancer` aprovisiona un balanceador gestionado (AWS NLB/ALB, Google Cloud Forwarding Rule, Azure Standard Load Balancer) que se factura por hora, además del tráfico procesado.

* Con un Service `LoadBalancer` por aplicación, el costo fijo crece con el número de aplicaciones.
* Con Gateway API, un único Gateway (un solo Service `LoadBalancer`) atiende muchas `HTTPRoute`: el costo fijo de red perimetral pasa a depender del número de Gateways, no del de aplicaciones.

### B. Direct Server Return (DSR)
Sin DSR, la respuesta del pod vuelve por el nodo que recibió la petición, lo que puede generar tráfico adicional entre zonas de disponibilidad (facturado por GB en los proveedores cloud).

* Con **Direct Server Return (DSR)**, Cilium entrega el paquete al pod preservando la IP del cliente y la respuesta sale directamente desde el nodo del pod.
* **Impacto FinOps**: reduce el tráfico entre nodos y zonas en aplicaciones con respuestas grandes.
* DSR requiere enrutamiento nativo (`routingMode: native`); en este laboratorio no está activado (se usa túnel VXLAN en un solo nodo).

---

## 3. Consideraciones para Entornos Locales (Minikube)

Para ejecutar este laboratorio sin saturar la máquina local de desarrollo:

* **Asignación usada en las pruebas**:
  * **vCPUs**: 2 núcleos.
  * **Memoria RAM**: 4 GB (4096 MB).
* **Comportamiento en Minikube**:
  * En local no se incurre en facturación monetaria, pero el consumo de RAM/CPU es visible en el host.
  * LB IPAM con anuncios L2 de Cilium emula un balanceador de nube asignando al Gateway una IP de la subred de minikube (`192.168.39.200`), sin `minikube tunnel` ni MetalLB.
