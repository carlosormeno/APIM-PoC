# PoC APIM – Modo Manual (sin Helm)

Este árbol contiene la versión **100% manual** (YAML + kubectl) de la PoC.

## Alcance
- WSO2 APIM y Gravitee APIM en modo manual.
- Kong se deja para el final.
- Todo se despliega con **manifests YAML** (Deployments, Services, Ingress, ConfigMaps, Secrets, etc.).
- Se permite **personalizar imágenes** si el producto lo requiere.

## Estructura
- `manual/docs/` runbooks y guía manual.
- `manual/docs/bitacora-ejecucion-poc-apim.md` bitacora viva de ejecucion.
- `manual/docs/informe-final-template-poc-apim.md` plantilla para informe final.
- `manual/manifests/` YAMLs por componente.
- `manual/backends/`, `manual/k6/`, `manual/vault/` duplicados para uso manual.
- `manual/images/` Dockerfiles si hay que customizar imágenes.

## Flujo recomendado
1) Ejecutar `manual/docs/runbook-0-base-apim-poc-manual.md`.
2) Desplegar WSO2 con `manual/docs/runbook-2-wso2-apim-manual.md`.
3) Desplegar Gravitee con `manual/docs/runbook-1-gravitee-apim-manual.md`.
4) Ejecutar pruebas y evidencias.

> Objetivo: mantener **control total** y trazabilidad sin Helm.
