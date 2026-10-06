# 01 · De Ingress a Gateway API

## 🧱 ¿Qué es (era) Ingress?

`Ingress` es el recurso histórico de Kubernetes para exponer servicios HTTP y
HTTPS hacia el exterior del clúster. El objeto `Ingress` define reglas de
enrutamiento (host + path → Service) y un **Ingress Controller** (NGINX,
Traefik, HAProxy…) es quien las ejecuta realmente.

```yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: demo
  annotations:
    nginx.ingress.kubernetes.io/rewrite-target: /   # ⚠️ específica de NGINX
spec:
  ingressClassName: nginx
  rules:
    - host: demo.local
      http:
        paths:
          - path: /
            pathType: Prefix
            backend:
              service:
                name: mi-app
                port:
                  number: 80
```

## ⚠️ Limitaciones de Ingress

1. **Solo HTTP/S.** TCP, UDP y gRPC requieren mecanismos por fuera del
   estándar (ConfigMaps, CRDs propietarios de cada controlador).
2. **Annotations no portables.** Todo lo útil (rewrites, rate-limit, canary,
   auth…) depende 100 % del controlador. Un `Ingress` escrito para NGINX no
   significa lo mismo en Traefik.
3. **Sin separación de roles.** Quien opera la infraestructura (TLS, puertos,
   DNS) y quien despliega aplicaciones (rutas) editan el mismo objeto →
   conflictos y permisos excesivos.
4. **Poco expresivo.** Matching limitado a host + path; sin pesos de tráfico,
   sin matching por headers ni query params en el estándar.
5. **Ecosistema fragmentado.** Cada controlador resolvió las carencias con sus
   propios CRDs (`IngressRoute` de Traefik, `TCPIngress` de Kong…), empeorando
   la portabilidad.

> 📌 **Ingress está congelado**: sigue soportado y no se eliminará, pero la
> comunidad ya no le añade funcionalidades. Además, `ingress-nginx` (el
> controlador comunitario más popular) fue **retirado en marzo de 2026**. Toda
> la innovación ocurre hoy en Gateway API.

## 🚪 Gateway API: la evolución oficial

Gateway API es una familia de CRDs mantenida por el **SIG-Network** de
Kubernetes. Alcanzó **GA (v1.0) en octubre de 2023** y va por **v1.6.x**.
Principios de diseño:

| Principio | Significado |
|---|---|
| **Orientado a roles** | Recursos separados para proveedor de infra, operador y desarrollador. |
| **Portable** | El mismo YAML funciona igual en cualquier controlador conforme. |
| **Expresivo** | Matching por header/query/método, pesos de tráfico, filtros tipados. |
| **Extensible** | Puntos de extensión definidos sin romper la portabilidad. |

### El mismo ejemplo, con Gateway API

```yaml
apiVersion: gateway.networking.k8s.io/v1
kind: Gateway
metadata:
  name: gateway-principal
spec:
  gatewayClassName: <controlador>        # istio | cilium | kong | traefik
  listeners:
    - name: http
      port: 80
      protocol: HTTP
---
apiVersion: gateway.networking.k8s.io/v1
kind: HTTPRoute
metadata:
  name: demo
spec:
  parentRefs:
    - name: gateway-principal
  hostnames:
    - demo.local
  rules:
    - backendRefs:
        - name: mi-app
          port: 80
```

Sin annotations propietarias y portable entre controladores.
👉 Detalle de cada recurso en
[`02-recursos-de-gateway-api.md`](02-recursos-de-gateway-api.md).

## 📊 Comparación rápida

| Criterio | Ingress | Gateway API |
|---|---|---|
| Protocolos | HTTP/S | HTTP, HTTPS, gRPC, TCP, UDP, TLS |
| Roles separados | ❌ | ✅ |
| Config avanzada | Annotations propietarias | Campos tipados del estándar |
| Portabilidad | Baja | Alta (tests de conformidad) |
| Multi-namespace | Limitado | Nativo (`ReferenceGrant`) |
| Estado del proyecto | Congelado | Activo (GA desde 2023) |

## ❓ ¿Ingress desaparece?

No. Seguirá funcionando por años. Pero los desarrollos nuevos (service mesh,
canary nativo, multi-protocolo) se construyen sobre Gateway API — por eso este
laboratorio trabaja directamente con sus implementaciones: **Istio, Cilium,
Kong y Traefik**.

## 📚 Referencias

- <https://gateway-api.sigs.k8s.io/>
- <https://kubernetes.io/docs/concepts/services-networking/ingress/>
- <https://gateway-api.sigs.k8s.io/guides/migrating-from-ingress/>
