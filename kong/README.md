# 🚪 Kong — Implementación Gateway API

> **Equipo:** _por definir_ · **Rama de trabajo:** `equipo/kong`

Este es el espacio del equipo **Kong**. Documenta tu trabajo en **este mismo
README**, reemplazando este contenido por la estructura de la
[plantilla oficial](../plantillas/PLANTILLA-implementacion.md).

## 📌 Pistas para empezar

- Kong es un **API gateway** maduro; en Kubernetes se despliega con el
  **Kong Ingress Controller (KIC)** o el **Kong Gateway Operator**.
- La vía habitual es Helm (charts oficiales de Kong); verifica en la
  documentación cómo se habilita el soporte de Gateway API en la versión
  actual y qué `GatewayClass` registra (habitualmente `kong`).
- Un diferencial de Kong es su ecosistema de **plugins** (auth, rate-limit,
  CORS…): si exploras alguno, documéntalo en la sección de funcionalidades
  adicionales.
- Docs oficiales: <https://docs.konghq.com/kubernetes-ingress-controller/>
- Estado de conformidad: <https://gateway-api.sigs.k8s.io/implementations/#kong-kubernetes-ingress-controller>

## 📁 Estructura esperada

```text
kong/
├── README.md        ← tu documentación (usa la plantilla)
├── manifests/       ← YAMLs finales, ordenados y comentados
└── evidencias/      ← capturas, salidas de terminal, diagramas
```

## ⚠️ Reglas rápidas

1. Trabaja solo dentro de esta carpeta y en tu rama `equipo/kong`.
2. Todo merge a `main` es por PR aprobado — ver
   [`CONTRIBUTING.md`](../CONTRIBUTING.md).
3. Tus manifiestos deben funcionar en un clúster limpio siguiendo tu README.
