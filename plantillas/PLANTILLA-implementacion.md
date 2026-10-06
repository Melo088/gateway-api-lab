# 🧩 Implementación: <CONTROLADOR>

> **Equipo:** _Nombre 1 · Nombre 2_  |  **Rama:** `equipo/<controlador>`  |  **Fecha:** _dd/mm/aaaa_

<!--
INSTRUCCIONES:
- Copia esta plantilla como el README.md de tu carpeta y rellena cada sección.
- El texto en cursiva es guía: bórralo al completar.
- Si una sección no aplica, justifícalo brevemente (no la elimines).
-->

## 1. Introducción

_¿Qué es <CONTROLADOR>? ¿Quién lo mantiene? ¿De dónde viene (ingress
controller, service mesh, CNI…)? 5–10 líneas._

## 2. Arquitectura

_Componentes que participan (control plane, data plane, proxies…). Incluye un
diagrama propio (imagen en `evidencias/` o Mermaid)._

## 3. Requisitos previos

- _Clúster usado (herramienta y versión de Kubernetes)._
- _Versiones: kubectl, helm, <controlador>._
- _Recursos mínimos (CPU / RAM)._
- _¿Requiere los CRDs de Gateway API preinstalados o los trae?_

## 4. Instalación

_Paso a paso con comandos exactos y verificación después de cada paso
relevante._

```bash
# ejemplo de formato
helm install ...
kubectl -n <namespace> get pods
```

## 5. Configuración de Gateway API

_GatewayClass que registra el controlador, Gateway creado, explicación de los
listeners configurados._

## 6. Caso de uso: enrutamiento HTTP

_Despliegue de la app de prueba + HTTPRoute + prueba real con `curl` o
navegador. Incluye comandos y salidas reales._

## 7. Funcionalidades adicionales (opcional, suma puntos)

_TLS, canary con weights, matching por headers, redirects, CORS… lo que
explore el equipo._

## 8. Verificación y pruebas

_Tabla de pruebas ejecutadas:_

| # | Qué se probó | Comando | Resultado esperado | Resultado obtenido |
|---|---|---|---|---|
| 1 |  |  |  |  |

## 9. Troubleshooting

_Errores encontrados durante la implementación y cómo se resolvieron
(mínimo 2; todos los equipos se encontrarán con varios 😄)._

## 10. Conclusiones

_Fortalezas y debilidades del controlador, curva de aprendizaje, en qué
escenarios lo elegirían._

## 11. Referencias

- _Enlaces oficiales y fuentes usadas._

---

## ✅ Definition of Done (revisar antes de abrir el PR)

- [ ] Todas las secciones completas (o justificadas).
- [ ] Manifiestos finales en `manifests/`, funcionando **desde cero** en un clúster limpio.
- [ ] Evidencias en `evidencias/` y referenciadas desde este README.
- [ ] Comandos copiables y reproducibles.
- [ ] Redacción en español, formato consistente con la plantilla.
- [ ] Sin secretos, kubeconfigs ni archivos temporales.
