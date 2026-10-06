# 🚪 Traefik — Implementación Gateway API

> **Equipo:** _por definir_ · **Rama de trabajo:** `equipo/traefik`

Este es el espacio del equipo **Traefik**. Documenta tu trabajo en **este
mismo README**, reemplazando este contenido por la estructura de la
[plantilla oficial](../plantillas/PLANTILLA-implementacion.md).

## 📌 Pistas para empezar

- Traefik es un **reverse proxy / ingress controller** cloud-native muy usado;
  en su versión **v3** el soporte de Gateway API llegó a madurez.
- Instalación habitual con Helm (`traefik/traefik`); el provider de Gateway
  API se **habilita explícitamente** en los values del chart (busca
  `providers.kubernetesGateway`).
- Verifica si debes instalar los CRDs de Gateway API por separado según tu
  versión (ver [`docs/03`](../docs/03-levantar-el-entorno.md)).
- Docs oficiales: <https://doc.traefik.io/traefik/>
- Estado de conformidad: <https://gateway-api.sigs.k8s.io/implementations/#traefik-proxy>

## 📁 Estructura esperada

```text
traefik/
├── README.md        ← tu documentación (usa la plantilla)
├── manifests/       ← YAMLs finales, ordenados y comentados
└── evidencias/      ← capturas, salidas de terminal, diagramas
```

## ⚠️ Reglas rápidas

1. Trabaja solo dentro de esta carpeta y en tu rama `equipo/traefik`.
2. Todo merge a `main` es por PR aprobado — ver
   [`CONTRIBUTING.md`](../CONTRIBUTING.md).
3. Tus manifiestos deben funcionar en un clúster limpio siguiendo tu README.
