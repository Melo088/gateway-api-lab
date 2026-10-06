# Contribución

## Ramas

| Rama | Alcance |
|---|---|
| `main` | Contenido revisado. Protegida: solo admite cambios por Pull Request. |
| `equipo/istio` | `istio/` |
| `equipo/cilium` | `cilium/` |
| `equipo/kong` | `kong/` |
| `equipo/traefik` | `traefik/` |

- Cada rama modifica únicamente su carpeta.
- Cambios en `docs/`, `plantillas/` o archivos raíz se proponen en un Pull
  Request independiente.
- Las ramas se sincronizan con `main` antes de abrir un Pull Request:

```bash
git checkout equipo/<implementacion>
git pull origin main
```

## Commits

[Conventional Commits](https://www.conventionalcommits.org/es/), con la
implementación como scope:

```text
docs(istio): documentar instalación con istioctl
feat(kong): agregar HTTPRoute con distribución 90/10
fix(cilium): corregir puerto del listener HTTPS
chore: actualizar .gitignore
```

| Tipo | Uso |
|---|---|
| `docs` | Documentación |
| `feat` | Manifiestos, ejemplos, scripts |
| `fix` | Correcciones |
| `chore` | Mantenimiento |

## Pull Requests

1. `git push origin equipo/<implementacion>`
2. Abrir Pull Request hacia `main` con título `[<Implementación>] <resumen>`.
3. Completar la plantilla del Pull Request.
4. Resolver los comentarios de revisión.

Condiciones de merge:

- Una aprobación del code owner.
- Conversaciones resueltas.
- Rama actualizada con `main`.

Push directo y force push a `main` están bloqueados.

## Estilo de documentación

- Español, registro técnico.
- Sin emojis.
- Comandos en bloques `bash`; manifiestos en bloques `yaml`.
- Versiones explícitas de cada componente instalado.
- Comandos reproducibles en un clúster limpio, en el orden documentado.
- Salidas de comandos en bloques `text`, recortadas a lo relevante.
- Enlaces internos con rutas relativas.
- Archivos de evidencia con nombres descriptivos en minúsculas y guiones
  (`gateway-programmed.png`).

## Manifiestos

- Un recurso o grupo de recursos relacionados por archivo.
- Prefijo numérico según orden de aplicación (`00-namespace.yaml`,
  `10-gateway.yaml`, `20-httproute.yaml`).
- Aplicables con `kubectl apply -f <implementacion>/manifests/`.

## Restricciones

- Sin secretos, kubeconfigs ni claves privadas.
- Sin archivos binarios mayores a 2 MB.
- Sin mensajes de commit genéricos (`wip`, `cambios`, `update`).
