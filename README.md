# gateway-api-lab

Repositorio de referencia para implementar y documentar controladores de
Kubernetes Gateway API: Istio, Cilium, Kong y Traefik.

## Ingress

`Ingress` (`networking.k8s.io/v1`) es el recurso original de Kubernetes para
exponer Services HTTP/HTTPS fuera del clúster. Define reglas de host y path
hacia un Service; un Ingress Controller las ejecuta.

Limitaciones:

- Soporte nativo solo para HTTP y HTTPS.
- Funcionalidad avanzada (rewrites, canary, rate limiting) dependiente de
  annotations propias de cada controlador, lo que impide la portabilidad.
- Un único objeto mezcla configuración de infraestructura (puertos, TLS) y de
  aplicación (rutas).
- Annotations sin validación de esquema.

La API de Ingress está congelada: se mantiene, pero no recibe nuevas
funcionalidades. El controlador `ingress-nginx` fue retirado en marzo de 2026.

## Gateway API

Gateway API es el sucesor de Ingress, mantenido por SIG-Network. Es un conjunto
de CRDs (`gateway.networking.k8s.io`), GA desde v1.0 (octubre de 2023), con
v1.6.2 como versión estable actual. Sus características principales:

- Modelo orientado a roles: cada recurso corresponde a un responsable distinto.
- Portabilidad entre implementaciones, verificada con pruebas de conformidad.
- Soporte para HTTP, HTTPS, gRPC, TLS, TCP y UDP.
- Matching por path, headers, query params y método; pesos de tráfico y
  filtros tipados en la especificación.

| Recurso | Responsable | Función |
|---|---|---|
| `GatewayClass` | Proveedor de infraestructura | Declara el controlador que implementa los Gateways. |
| `Gateway` | Operador del clúster | Define listeners: puertos, protocolos, hostnames y TLS. |
| `HTTPRoute`, `GRPCRoute`, `TLSRoute`, ... | Desarrollador de la aplicación | Define el enrutamiento hacia los Services. |

Detalle en [`docs/01-de-ingress-a-gateway-api.md`](docs/01-de-ingress-a-gateway-api.md)
y [`docs/02-recursos-de-gateway-api.md`](docs/02-recursos-de-gateway-api.md).

## Estructura

```text
.
├── comun/
│   ├── base/          Namespace, backends httpbin v1/v2 y Gateway
│   └── escenarios/    HTTPRoutes de los escenarios E01-E07
├── scripts/           Certificado TLS de prueba y verificación de escenarios
├── docs/              Conceptos, preparación del entorno y escenarios
├── plantillas/        Plantillas de documentación y de overlay kustomize
├── istio/             Implementación Istio
├── cilium/            Implementación Cilium
├── kong/              Implementación Kong
├── traefik/           Implementación Traefik
├── .github/           CODEOWNERS, plantilla de Pull Request y validación CI
└── CONTRIBUTING.md    Ramas, commits, Pull Requests y estilo
```

Cada carpeta de implementación contiene:

```text
<implementacion>/
├── README.md          Documentación según plantillas/PLANTILLA-implementacion.md
├── instalacion/       Values de Helm, perfiles u otros archivos de instalación del controlador
├── manifests/         Overlay kustomize sobre comun/ y recursos propios del controlador
└── evidencias/        Capturas, salidas de comandos y diagramas
```

Los manifiestos de `comun/` son los mismos para todas las implementaciones; cada
overlay solo define la GatewayClass y los ajustes que exija su controlador.

## Uso

```bash
# Clúster con CRDs de Gateway API: docs/03-levantar-el-entorno.md
# Controlador instalado:           <implementacion>/README.md

scripts/crear-certificado.sh
kubectl apply -k <implementacion>/manifests
scripts/verificar.sh
```

Escenarios, convenciones, acceso al Gateway y uso en un clúster propio:
[`docs/04-escenarios.md`](docs/04-escenarios.md).

## Flujo de trabajo

- `main` está protegida; solo recibe cambios mediante Pull Request aprobado por
  el code owner.
- Cada implementación se desarrolla en su rama: `equipo/istio`,
  `equipo/cilium`, `equipo/kong`, `equipo/traefik`.
- Commits según [Conventional Commits](https://www.conventionalcommits.org/es/).

Reglas completas en [`CONTRIBUTING.md`](CONTRIBUTING.md).

## Referencias

- [Gateway API](https://gateway-api.sigs.k8s.io/)
- [Implementaciones y conformidad](https://gateway-api.sigs.k8s.io/implementations/)
- [Migración desde Ingress](https://gateway-api.sigs.k8s.io/guides/migrating-from-ingress/)
