# <Implementación>

| Campo | Valor |
|---|---|
| Integrantes | |
| Rama | `equipo/<implementacion>` |
| Versión del controlador | |
| Versión de Gateway API | |
| Clúster y versión de Kubernetes | |

<!--
Reemplazar el README.md de la carpeta con esta estructura.
Conservar todas las secciones; si una no aplica, indicar el motivo.
-->

## 1. Descripción

Origen, mantenedor y tipo de componente (service mesh, CNI, API gateway,
reverse proxy).

## 2. Arquitectura

Componentes de control plane y data plane, y flujo de una petición. Incluir
diagrama (Mermaid o imagen en `evidencias/`).

## 3. Requisitos

Versiones, recursos mínimos y dependencias, incluidos los CRDs de Gateway API
requeridos.

## 4. Instalación

Comandos en orden de ejecución, con verificación después de cada paso.

## 5. GatewayClass y Gateway

GatewayClass registrada por el controlador, Gateway desplegado, listeners y
recursos que aprovisiona el controlador (Deployment, Service).

## 6. Enrutamiento HTTP

HTTPRoute hacia el backend de prueba ([`docs/manifests/httpbin.yaml`](../docs/manifests/httpbin.yaml))
y verificación con `curl`.

## 7. Funcionalidades adicionales

TLS, distribución por pesos, matching por headers, redirects, CORS, extensiones
propias del controlador.

## 8. Pruebas

| # | Caso | Comando | Resultado esperado | Resultado obtenido |
|---|---|---|---|---|
| 1 | | | | |

## 9. Troubleshooting

| Síntoma | Causa | Solución |
|---|---|---|
| | | |

## 10. Limpieza

Comandos para eliminar todos los recursos creados.

## 11. Análisis

Ventajas, limitaciones, nivel de conformidad con Gateway API y casos de uso
adecuados.

## 12. Referencias

## Checklist

- [ ] Secciones completas o con motivo de omisión.
- [ ] Manifiestos en `manifests/` probados desde un clúster limpio.
- [ ] Evidencias en `evidencias/` referenciadas desde este README.
- [ ] Versiones explícitas de todos los componentes.
