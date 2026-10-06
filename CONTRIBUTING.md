# 🤝 Guía de contribución

Este repositorio es colaborativo: 4 equipos documentan e implementan un
controlador de Gateway API cada uno. Estas reglas existen para que todo el
trabajo termine **mergeado en `main` con el mismo estilo**.

## 🔀 Modelo de ramas

| Rama | Propósito | ¿Quién escribe? |
|---|---|---|
| `main` | Contenido revisado y aprobado. **Protegida.** | Nadie directamente (solo vía PR). |
| `equipo/istio` | Trabajo del equipo Istio | Equipo 1 |
| `equipo/cilium` | Trabajo del equipo Cilium | Equipo 2 |
| `equipo/kong` | Trabajo del equipo Kong | Equipo 3 |
| `equipo/traefik` | Trabajo del equipo Traefik | Equipo 4 |

```bash
# Cambiarte a tu rama (ya existe en el remoto)
git checkout equipo/<tu-controlador>

# Mantenerla al día con main regularmente
git pull origin main
```

> **Regla de oro:** trabaja únicamente dentro de la carpeta de tu equipo
> (`istio/`, `cilium/`, `kong/` o `traefik/`). Los cambios a `docs/` o
> `plantillas/` se proponen por PR aparte y se acuerdan con todos.

## ✍️ Convención de commits

Usamos [Conventional Commits](https://www.conventionalcommits.org/es/) en
español, con el controlador como scope:

```text
docs(istio): completar sección de instalación
feat(kong): agregar ejemplo de canary 90/10
fix(cilium): corregir puerto del listener https
chore: actualizar .gitignore
```

| Prefijo | Uso |
|---|---|
| `docs:` | documentación |
| `feat:` | manifiestos, ejemplos, scripts |
| `fix:` | correcciones |
| `chore:` | mantenimiento |

## 🔁 Pull Requests

1. Empuja tu rama: `git push origin equipo/<tu-controlador>`.
2. Abre el PR hacia `main`. Título con formato: `[<Controlador>] <resumen>`
   (ej. `[Cilium] Implementación y documentación completa`).
3. Llena la **plantilla de PR** (aparece automáticamente).
4. Solicita revisión a **@Melo088** (code owner).
5. Atiende los comentarios hasta la aprobación.

**Requisitos para merge a `main`:**

- ✅ 1 aprobación del code owner (la revisión es obligatoria).
- ✅ Checklist del PR completo.
- ✅ Conversaciones de revisión resueltas.
- ❌ Push directo a `main` está bloqueado (incluye force push).

## 📐 Estilo de documentación

- Español neutro, tono técnico pero claro.
- Comandos en bloques ` ```bash `, manifiestos en ` ```yaml `.
- Capturas en `evidencias/` con nombres descriptivos
  (`instalacion-pods-ok.png`, no `Captura1.png`).
- Referencia archivos del repo con rutas relativas.
- Todo comando documentado debe ser **copiable y reproducible** en un clúster
  limpio siguiendo tu README.

## 🚫 Qué evitar

- Push directo a `main`.
- Editar la carpeta de otro equipo sin acordarlo.
- Subir secretos, `kubeconfig` o archivos pesados (> 1–2 MB).
- Commits tipo `wip`, `cambios`, `asdf`.

## ✅ Definition of Done

Antes de abrir el PR final, verifica el checklist de la
[plantilla de implementación](plantillas/PLANTILLA-implementacion.md).
