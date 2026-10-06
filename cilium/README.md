# 🚪 Cilium — Implementación Gateway API

> **Equipo:** _por definir_ · **Rama de trabajo:** `equipo/cilium`

Este es el espacio del equipo **Cilium**. Documenta tu trabajo en **este mismo
README**, reemplazando este contenido por la estructura de la
[plantilla oficial](../plantillas/PLANTILLA-implementacion.md).

## 📌 Pistas para empezar

- Cilium es una **CNI basada en eBPF**: aquí el gateway vive en la propia capa
  de red del clúster (enfoque muy distinto a un ingress clásico — ¡buen ángulo
  para las conclusiones!).
- Instalación con Helm (`cilium/cilium`); el soporte de Gateway API se
  **habilita explícitamente** (busca el valor `gatewayAPI.enabled` en los
  values del chart).
- Cilium **requiere que los CRDs de Gateway API estén instalados antes** de
  habilitar la función (ver [`docs/03`](../docs/03-levantar-el-entorno.md)).
- Considera la compatibilidad con tu herramienta de clúster (minikube/kind) —
  documéntala en tus requisitos.
- Docs oficiales: <https://docs.cilium.io/en/stable/>
- Estado de conformidad: <https://gateway-api.sigs.k8s.io/implementations/#cilium>

## 📁 Estructura esperada

```text
cilium/
├── README.md        ← tu documentación (usa la plantilla)
├── manifests/       ← YAMLs finales, ordenados y comentados
└── evidencias/      ← capturas, salidas de terminal, diagramas
```

## ⚠️ Reglas rápidas

1. Trabaja solo dentro de esta carpeta y en tu rama `equipo/cilium`.
2. Todo merge a `main` es por PR aprobado — ver
   [`CONTRIBUTING.md`](../CONTRIBUTING.md).
3. Tus manifiestos deben funcionar en un clúster limpio siguiendo tu README.
