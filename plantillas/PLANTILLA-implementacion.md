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

GatewayClass registrada por el controlador, contenido del overlay
(`manifests/kustomization.yaml`) y recursos que el controlador aprovisiona para
el Gateway (Deployment, Service).

## 6. Escenarios comunes

Resultado de [`scripts/verificar.sh`](../scripts/verificar.sh) sobre los
escenarios de [`docs/04-escenarios.md`](../docs/04-escenarios.md).

```text
salida de scripts/verificar.sh
```

| ID | Resultado | Observaciones |
|---|---|---|
| E01 | | |
| E02 | | |
| E03 | | |
| E04 | | |
| E05 | | |
| E06 | | |
| E07 | | |

## 7. Comportamiento específico

Diferencias observadas frente a la especificación, funcionalidades no
soportadas y alternativas propias del controlador.

## 8. Extensiones del controlador

Funcionalidades fuera de Gateway API (policies, plugins, CRDs propios) con
manifiestos en `manifests/` y prueba de funcionamiento.

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
- [ ] `scripts/verificar.sh` ejecutado desde un clúster limpio; salida incluida en la sección 6.
- [ ] Evidencias en `evidencias/` referenciadas desde este README.
- [ ] Versiones explícitas de todos los componentes.
