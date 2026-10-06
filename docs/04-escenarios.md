# 04. Escenarios comunes

Conjunto de pruebas idéntico para todas las implementaciones. Los manifiestos en
[`comun/`](../comun) no dependen del controlador: solo cambia
`spec.gatewayClassName` del Gateway (y, si el controlador lo exige, los puertos
de los listeners).

## Convenciones

| Elemento | Valor |
|---|---|
| Namespace | `gateway-lab` |
| Gateway | `gateway` |
| Listener `http` | puerto 80, hostname `*.lab.local` |
| Listener `https` | puerto 443, hostname `*.lab.local`, Secret `gateway-tls` |
| Backends | Services `httpbin-v1` y `httpbin-v2`, puerto 8080 |
| HTTPRoutes | `eNN-<escenario>`, un hostname por escenario |

Cada escenario usa un hostname propio, por lo que todos coexisten en el mismo
Gateway sin interferencias.

## Escenarios

| ID | Hostname | Funcionalidad | Soporte | Prueba | Resultado esperado |
|---|---|---|---|---|---|
| E01 | `enrutamiento.lab.local` | Enrutamiento por hostname y path | Core | `GET /get` | 200 |
| E02 | `match.lab.local` | Matching por header `x-version: v2` | Core | `GET /hostname` con y sin header | `httpbin-v2` con header, `httpbin-v1` sin header |
| E03 | `pesos.lab.local` | Distribución 80/20 entre v1 y v2 | Core | 100 x `GET /hostname` | Entre 8 y 35 respuestas de `httpbin-v2` |
| E04 | `headers.lab.local` | `RequestHeaderModifier`, `ResponseHeaderModifier` | Core, Extended | `GET /headers` | `x-gateway-lab` en la petición recibida y en la respuesta |
| E05 | `rewrite.lab.local` | `URLRewrite` `/api/<ruta>` a `/<ruta>` | Extended | `GET /api/status/200` | 200 |
| E06 | `redirect.lab.local` | `RequestRedirect` HTTP a HTTPS | Core | `GET http://.../get` | 301, `Location: https://redirect.lab.local/...` |
| E07 | `tls.lab.local` | Terminación TLS en el Gateway | Core | `GET https://.../get` | 200 |

El nivel de soporte corresponde a la especificación de Gateway API. Una
funcionalidad Extended puede no estar implementada; en ese caso se documenta el
resultado y, si existe, la alternativa propia del controlador.

## Ejecución

Requisitos: clúster con CRDs de Gateway API ([`03`](03-levantar-el-entorno.md))
y el controlador instalado según su README.

```bash
# 1. Secret TLS para el listener https
scripts/crear-certificado.sh

# 2. Base común y escenarios con la GatewayClass del controlador
kubectl apply -k <implementacion>/manifests

# 3. Estado
kubectl -n gateway-lab get gateway gateway
kubectl -n gateway-lab get httproute

# 4. Pruebas
scripts/verificar.sh
```

## Acceso al Gateway

`scripts/verificar.sh` toma la dirección de `status.addresses` del Gateway. Las
peticiones se envían con `curl --connect-to`, por lo que no requiere entradas en
`/etc/hosts` ni DNS.

Si el Gateway no obtiene dirección (Service `LoadBalancer` en `<pending>`):

```bash
kubectl -n <namespace-del-servicio> get svc          # Service creado por el controlador
kubectl -n <namespace-del-servicio> port-forward svc/<servicio> 8080:80 8443:443

GATEWAY_ADDRESS=127.0.0.1 HTTP_PORT=8080 HTTPS_PORT=8443 scripts/verificar.sh
```

| Variable | Valor por defecto |
|---|---|
| `NAMESPACE` | `gateway-lab` |
| `GATEWAY` | `gateway` |
| `GATEWAY_ADDRESS` | `status.addresses[0].value` del Gateway |
| `HTTP_PORT` | `80` |
| `HTTPS_PORT` | `443` |
| `DOMINIO` | `lab.local` |

Prueba manual de un escenario:

```bash
curl -i --connect-to enrutamiento.lab.local:80:<direccion>:<puerto> http://enrutamiento.lab.local/get
```

## Uso en un clúster propio

La base se referencia de forma remota desde cualquier kustomization, sin clonar
el repositorio:

```yaml
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization
resources:
  - https://github.com/Melo088/gateway-api-lab//comun?ref=main
patches:
  - target:
      kind: Gateway
      name: gateway
    patch: |-
      - op: replace
        path: /spec/gatewayClassName
        value: <gatewayclass>
```

```bash
kubectl get gatewayclass       # GatewayClass disponibles en el clúster
kubectl apply -k <directorio>
```

## Limpieza

```bash
kubectl delete -k <implementacion>/manifests    # incluye el namespace gateway-lab y el Secret TLS
```
