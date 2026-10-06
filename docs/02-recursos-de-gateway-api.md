# 02 · Recursos de Gateway API

## 🧭 Modelo general

```text
Proveedor infra        Operador plataforma         Equipo aplicación
      │                       │                           │
      ▼                       ▼                           ▼
 GatewayClass  ───────►    Gateway   ───────►   HTTPRoute / GRPCRoute /
 (el "tipo" de           (listeners,            TCPRoute / TLSRoute…
  gateway)                puertos, TLS)               │
                                                      ▼
                                                   Services
```

## 1️⃣ GatewayClass

Define el **tipo** de Gateway y qué controlador lo implementa. Es un recurso a
nivel de clúster y **normalmente lo crea la instalación del controlador** (no
suele ser necesario crearlo a mano).

```yaml
apiVersion: gateway.networking.k8s.io/v1
kind: GatewayClass
metadata:
  name: ejemplo
spec:
  controllerName: example.net/gateway-controller
```

```bash
kubectl get gatewayclass   # ver las disponibles tras instalar un controlador
```

## 2️⃣ Gateway

Punto de entrada del tráfico. Define **listeners**: puerto, protocolo, hostname
y TLS. Lo gestiona el rol de plataforma.

```yaml
apiVersion: gateway.networking.k8s.io/v1
kind: Gateway
metadata:
  name: gateway-principal
  namespace: default
spec:
  gatewayClassName: <controlador>
  listeners:
    - name: http
      port: 80
      protocol: HTTP
      allowedRoutes:            # qué rutas se pueden adjuntar
        namespaces:
          from: Same            # Same | All | Selector
```

## 3️⃣ HTTPRoute (la estrella)

Reglas de enrutamiento HTTP. Se **adjunta** a un Gateway vía `parentRefs` y la
gestiona el equipo de aplicación.

```yaml
apiVersion: gateway.networking.k8s.io/v1
kind: HTTPRoute
metadata:
  name: mi-app
spec:
  parentRefs:
    - name: gateway-principal
  hostnames:
    - "demo.local"
  rules:
    - matches:
        - path:
            type: PathPrefix
            value: /api
      filters:
        - type: RequestHeaderModifier
          requestHeaderModifier:
            add:
              - name: x-equipo
                value: plataformas2
      backendRefs:
        - name: mi-app
          port: 8080
```

Capacidades que Ingress no tenía en el estándar:

- **Matching** por path, header, query param y método.
- **Filtros**: `URLRewrite`, `RequestRedirect`, `RequestHeaderModifier`,
  `CORS` (v1.5+), extensiones del controlador.
- **Pesos en backendRefs** → canary nativo:

```yaml
      backendRefs:
        - name: app-v1
          port: 8080
          weight: 90
        - name: app-v2
          port: 8080
          weight: 10
```

- **Timeouts** tipados en la regla (`timeouts.request`).

## 4️⃣ Otras rutas

| Recurso | Canal | Uso |
|---|---|---|
| `GRPCRoute` | Standard (v1) | gRPC |
| `TLSRoute` | Standard (v1, desde v1.5) | TLS passthrough/SNI |
| `TCPRoute` / `UDPRoute` | Experimental (`v1alpha2`) | L4 genérico |

## 5️⃣ ReferenceGrant

Permite referencias **entre namespaces** de forma segura (ej. un `HTTPRoute` en
`app` apuntando a un `Service` en `backend`). Sin él, la referencia se rechaza.

## 6️⃣ Estado y verificación

Los recursos reportan condiciones estándar: `Accepted`, `Programmed`,
`ResolvedRefs`. Comandos útiles:

```bash
kubectl get gatewayclass
kubectl get gateway -A
kubectl get httproute -A
kubectl describe gateway gateway-principal     # conditions y listeners
kubectl describe httproute mi-app              # si fue aceptada y por qué
```

## 7️⃣ Canales de instalación: Standard vs Experimental

- **Standard**: solo lo GA (GatewayClass, Gateway, HTTPRoute, GRPCRoute,
  TLSRoute, ReferenceGrant…).
- **Experimental**: lo Standard + features alpha (TCPRoute, UDPRoute,
  ListenerSet…). Los CRDs son tan grandes que requieren
  `kubectl apply --server-side=true`.

Comandos de instalación en [`03-levantar-el-entorno.md`](03-levantar-el-entorno.md).

## 📚 Referencias

- <https://gateway-api.sigs.k8s.io/concepts/api-overview/>
- <https://gateway-api.sigs.k8s.io/guides/>
