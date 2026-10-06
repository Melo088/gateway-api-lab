# 🚪 Istio — Implementación Gateway API

> **Equipo:** _por definir_ · **Rama de trabajo:** `equipo/istio`

Este es el espacio del equipo **Istio**. Documenta tu trabajo en **este mismo
README**, reemplazando este contenido por la estructura de la
[plantilla oficial](../plantillas/PLANTILLA-implementacion.md).

## 📌 Pistas para empezar

- Istio es un **service mesh** cuyo ingress gateway soporta Gateway API de
  forma nativa: al crear un `Gateway` con `gatewayClassName: istio`, Istio
  aprovisiona automáticamente el gateway (Deployment + Service).
- Instalación habitual: `istioctl install` o Helm (`base` + `istiod`).
- Verifica si tu versión de Istio instala los CRDs de Gateway API o si debes
  instalarlos antes (ver [`docs/03`](../docs/03-levantar-el-entorno.md)).
- Docs oficiales: <https://istio.io/latest/docs/tasks/traffic-management/ingress/gateway-api/>
- Estado de conformidad: <https://gateway-api.sigs.k8s.io/implementations/#istio>

## 📁 Estructura esperada

```text
istio/
├── README.md        ← tu documentación (usa la plantilla)
├── manifests/       ← YAMLs finales, ordenados y comentados
└── evidencias/      ← capturas, salidas de terminal, diagramas
```

## ⚠️ Reglas rápidas

1. Trabaja solo dentro de esta carpeta y en tu rama `equipo/istio`.
2. Todo merge a `main` es por PR aprobado — ver
   [`CONTRIBUTING.md`](../CONTRIBUTING.md).
3. Tus manifiestos deben funcionar en un clúster limpio siguiendo tu README.
