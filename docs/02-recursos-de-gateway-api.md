# 02. Recursos de Gateway API

## Modelo

```text
Proveedor de infraestructura   Operador del clúster      Desarrollador
            |                          |                       |
       GatewayClass  -------------> Gateway  -------------> xRoute  -----> Service
   (controlador)             (listeners, TLS)         (reglas de enrutamiento)
```

## GatewayClass

Recurso de ámbito clúster que asocia un nombre con el controlador que lo
implementa. Normalmente lo crea la instalación del controlador.

```yaml
apiVersion: gateway.networking.k8s.io/v1
kind: GatewayClass
metadata:
  name: ejemplo
spec:
  controllerName: example.net/gateway-controller
```

## Gateway

Instancia de punto de entrada. Define listeners con puerto, protocolo, hostname,
TLS y qué rutas pueden adjuntarse.

```yaml
apiVersion: gateway.networking.k8s.io/v1
kind: Gateway
metadata:
  name: gateway
  namespace: default
spec:
  gatewayClassName: <gatewayclass>
  listeners:
    - name: http
      port: 80
      protocol: HTTP
      allowedRoutes:
        namespaces:
          from: Same            # Same | All | Selector
```

## HTTPRoute

Reglas de enrutamiento HTTP. Se adjunta a uno o varios Gateways mediante
`parentRefs`.

```yaml
apiVersion: gateway.networking.k8s.io/v1
kind: HTTPRoute
metadata:
  name: mi-app
spec:
  parentRefs:
    - name: gateway
  hostnames:
    - demo.local
  rules:
    - matches:
        - path:
            type: PathPrefix
            value: /api
      filters:
        - type: RequestHeaderModifier
          requestHeaderModifier:
            add:
              - name: x-env
                value: lab
      backendRefs:
        - name: mi-app
          port: 8080
```

Capacidades definidas en la especificación:

- Matching por path, header, query param y método.
- Filtros: `RequestHeaderModifier`, `ResponseHeaderModifier`, `URLRewrite`,
  `RequestRedirect`, `RequestMirror`, `CORS`, `ExtensionRef`.
- Distribución de tráfico por pesos:

```yaml
      backendRefs:
        - name: app-v1
          port: 8080
          weight: 90
        - name: app-v2
          port: 8080
          weight: 10
```

- Timeouts por regla (`timeouts.request`, `timeouts.backendRequest`).

## Otros tipos de ruta

| Recurso | Canal | Uso |
|---|---|---|
| `GRPCRoute` | Standard (`v1`) | gRPC |
| `TLSRoute` | Standard (`v1`, desde v1.5) | Enrutamiento por SNI, TLS passthrough |
| `TCPRoute`, `UDPRoute` | Experimental (`v1alpha2`) | Tráfico L4 |

## ReferenceGrant

Autoriza referencias entre namespaces, por ejemplo un `HTTPRoute` en `app` hacia
un `Service` en `backend`. Sin un `ReferenceGrant` en el namespace destino, la
referencia se rechaza.

## ListenerSet

Permite definir listeners en recursos separados del `Gateway` y adjuntarlos a
él. Standard desde v1.5.

## Estado

Los recursos publican condiciones en `status`: `Accepted`, `Programmed` y
`ResolvedRefs`.

```bash
kubectl get gatewayclass
kubectl get gateway -A
kubectl get httproute -A
kubectl describe gateway <nombre>
kubectl describe httproute <nombre>
```

## Canales de instalación

| Canal | Contenido |
|---|---|
| Standard | Recursos GA: GatewayClass, Gateway, HTTPRoute, GRPCRoute, TLSRoute, ListenerSet, ReferenceGrant, BackendTLSPolicy. |
| Experimental | Standard más recursos y campos en alpha (TCPRoute, UDPRoute, entre otros). Requiere `kubectl apply --server-side=true`. |

Instalación en [`03-levantar-el-entorno.md`](03-levantar-el-entorno.md).

## Referencias

- <https://gateway-api.sigs.k8s.io/concepts/api-overview/>
- <https://gateway-api.sigs.k8s.io/reference/spec/>
