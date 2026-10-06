# 01. De Ingress a Gateway API

## Ingress

`Ingress` define reglas de enrutamiento HTTP (host y path hacia un Service). Un
Ingress Controller (NGINX, Traefik, HAProxy, entre otros) observa esos objetos y
configura el proxy que atiende el tráfico.

```yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: demo
  annotations:
    nginx.ingress.kubernetes.io/rewrite-target: /   # específica de ingress-nginx
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

## Limitaciones

1. **Protocolos.** Solo HTTP y HTTPS. TCP, UDP y gRPC requieren ConfigMaps o
   CRDs propietarios.
2. **Portabilidad.** Rewrites, canary, rate limiting y autenticación se
   configuran con annotations específicas de cada controlador. Un mismo
   `Ingress` no se comporta igual en dos implementaciones.
3. **Roles.** Infraestructura (TLS, puertos) y aplicación (rutas) comparten un
   único objeto, lo que obliga a otorgar permisos amplios.
4. **Expresividad.** Matching limitado a host y path; sin pesos de tráfico ni
   matching por headers o query params en la especificación.
5. **Fragmentación.** Cada proveedor definió CRDs propios para cubrir estas
   carencias (`IngressRoute` en Traefik, `TCPIngress` en Kong, `VirtualService`
   en Istio).

La API de Ingress está congelada: continúa soportada, pero no recibe nuevas
funcionalidades. `ingress-nginx` fue retirado en marzo de 2026.

## Gateway API

Conjunto de CRDs del grupo `gateway.networking.k8s.io`, mantenido por
SIG-Network. GA en v1.0 (octubre de 2023); versión estable actual v1.6.2.

| Principio | Descripción |
|---|---|
| Orientado a roles | Recursos separados para proveedor, operador y desarrollador. |
| Portable | Comportamiento definido por la especificación y verificado con pruebas de conformidad. |
| Expresivo | Matching por header, query param y método; pesos; filtros tipados. |
| Extensible | Puntos de extensión definidos (`parametersRef`, filtros `ExtensionRef`, policies). |

### Equivalente con Gateway API

```yaml
apiVersion: gateway.networking.k8s.io/v1
kind: Gateway
metadata:
  name: gateway
spec:
  gatewayClassName: <gatewayclass>
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
    - name: gateway
  hostnames:
    - demo.local
  rules:
    - backendRefs:
        - name: mi-app
          port: 80
```

## Comparación

| Criterio | Ingress | Gateway API |
|---|---|---|
| Protocolos | HTTP, HTTPS | HTTP, HTTPS, gRPC, TLS, TCP, UDP |
| Separación de roles | No | Sí |
| Configuración avanzada | Annotations propietarias | Campos tipados de la especificación |
| Portabilidad | Baja | Alta (conformidad) |
| Referencias entre namespaces | No | Sí (`ReferenceGrant`) |
| Estado | Congelada | En desarrollo activo |

Ingress no se elimina de Kubernetes, pero las nuevas capacidades de
enrutamiento se desarrollan sobre Gateway API.

## Referencias

- <https://gateway-api.sigs.k8s.io/>
- <https://kubernetes.io/docs/concepts/services-networking/ingress/>
- <https://gateway-api.sigs.k8s.io/guides/migrating-from-ingress/>
