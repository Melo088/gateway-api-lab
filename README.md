# 🌐 gateway-api-lab

> Laboratorio comparativo de implementaciones de **Kubernetes Gateway API**:
> **Istio · Cilium · Kong · Traefik**
> Proyecto colaborativo — Plataformas 2.

## 📖 Contexto rápido

### ¿Qué era Ingress?

**Ingress** es el recurso clásico de Kubernetes para exponer tráfico HTTP/HTTPS
desde el exterior hacia los Services del clúster. Sigue funcionando, pero la API
está **congelada** (ya no recibe nuevas funcionalidades) por sus limitaciones:

- Solo soporta **HTTP/S** de forma nativa (nada de TCP, UDP o gRPC).
- La configuración útil se hace con **`annotations` propias de cada controlador**
  → manifiestos **no portables** entre vendors.
- **Mezcla responsabilidades**: infraestructura (TLS, puertos) y aplicación
  (rutas) editan el mismo objeto.
- Sin validación de tipos: un error en una annotation se descubre tarde.

Como dato: `ingress-nginx`, el controlador comunitario más usado, fue retirado en
**marzo de 2026**, lo que terminó de consolidar la migración hacia Gateway API.

### ¿Qué es Gateway API?

**Gateway API** es la evolución oficial de Ingress, mantenida por el
**SIG-Network** de Kubernetes (GA desde v1.0 en 2023; la versión actual es
**v1.6.x**). Es una familia de CRDs **orientada a roles**, **portable** entre
controladores y **multi-protocolo** (HTTP, HTTPS, gRPC, TCP, UDP, TLS).

| Recurso | Quién lo gestiona | Qué define |
|---|---|---|
| `GatewayClass` | Proveedor / plataforma | El "tipo" de gateway (el controlador que lo implementa). |
| `Gateway` | Operador de plataforma | Punto de entrada de tráfico: listeners, puertos, TLS. |
| `HTTPRoute` / `GRPCRoute` / `TCPRoute`… | Equipo de aplicación | Cómo enrutar el tráfico hacia los Services. |

➡️ Profundiza en [`docs/01-de-ingress-a-gateway-api.md`](docs/01-de-ingress-a-gateway-api.md)
y [`docs/02-recursos-de-gateway-api.md`](docs/02-recursos-de-gateway-api.md).

## 🗂️ Estructura del repositorio

```text
├── docs/               # Contexto teórico y guía para levantar el entorno
├── plantillas/         # Plantilla oficial de documentación por equipo
├── istio/              # Espacio de trabajo del equipo Istio
├── cilium/             # Espacio de trabajo del equipo Cilium
├── kong/               # Espacio de trabajo del equipo Kong
├── traefik/            # Espacio de trabajo del equipo Traefik
├── CONTRIBUTING.md     # Flujo de ramas, PRs y reglas de estilo
└── .github/            # Plantilla de PR y CODEOWNERS
```

Cada carpeta de equipo trae un `README.md` con pistas de inicio y dos
subcarpetas: `manifests/` (YAMLs) y `evidencias/` (capturas y salidas).

## 🚀 Cómo empezar

1. **Levanta tu clúster** siguiendo [`docs/03-levantar-el-entorno.md`](docs/03-levantar-el-entorno.md)
   (minikube, kind, k3d o nube — no estás atado a ninguno).
2. **Ubica tu carpeta** (`istio/`, `cilium/`, `kong/` o `traefik/`) y lee las
   pistas de su `README.md`.
3. **Documenta con la plantilla**:
   [`plantillas/PLANTILLA-implementacion.md`](plantillas/PLANTILLA-implementacion.md).
4. **Trabaja en tu rama** y abre PR cuando esté lista la entrega (ver abajo).

## 🔀 Flujo de trabajo (resumen)

- `main` está **protegida**: solo se actualiza mediante **Pull Request
  aprobado** por el dueño del repositorio.
- Cada equipo trabaja en su rama: `equipo/istio`, `equipo/cilium`,
  `equipo/kong`, `equipo/traefik`.
- Commits con [Conventional Commits](https://www.conventionalcommits.org/es/)
  (`docs:`, `feat:`, `fix:`…).
- Detalles completos en [`CONTRIBUTING.md`](CONTRIBUTING.md).

```bash
git checkout equipo/<tu-controlador>
# ... trabajar solo dentro de tu carpeta ...
git add . && git commit -m "docs(<controlador>): ..."
git push origin equipo/<tu-controlador>
# abrir PR hacia main desde GitHub
```

## 👥 Equipos

| Equipo | Controlador | Carpeta | Rama | Integrantes |
|---|---|---|---|---|
| 1 | Istio | [`istio/`](istio/) | `equipo/istio` | _por definir_ |
| 2 | Cilium | [`cilium/`](cilium/) | `equipo/cilium` | _por definir_ |
| 3 | Kong | [`kong/`](kong/) | `equipo/kong` | _por definir_ |
| 4 | Traefik | [`traefik/`](traefik/) | `equipo/traefik` | _por definir_ |

## 📚 Referencias

- [Gateway API — documentación oficial](https://gateway-api.sigs.k8s.io/)
- [Lista oficial de implementaciones y su conformidad](https://gateway-api.sigs.k8s.io/implementations/)
- [Guía de migración de Ingress a Gateway API](https://gateway-api.sigs.k8s.io/guides/migrating-from-ingress/)
