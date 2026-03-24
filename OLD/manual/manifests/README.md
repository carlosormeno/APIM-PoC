# Manifests manuales (sin Helm)

Este directorio contiene los YAMLs manuales para desplegar cada componente.

## Estructura
- `manual/manifests/base/` certificados, issuer, namespaces comunes
- `manual/manifests/ingress/` NGINX Ingress Controller
- `manual/manifests/observability/` Prometheus/Grafana/Loki/OTel
- `manual/manifests/backends/` backends PoC (opcional si no usas `manual/backends/`)
- `manual/manifests/wso2/` WSO2 APIM
- `manual/manifests/gravitee/` Gravitee APIM
- `manual/manifests/vault/` Vault (si no usas Helm)

## Convención
- Un archivo YAML por recurso crítico.
- Nombres claros: `00-namespace.yaml`, `10-deployment.yaml`, `20-service.yaml`, `30-ingress.yaml`.
- Registrar toda modificación en `changes.log`.

## Estado
Estos manifests son **plantillas**. Se completan durante la instalación manual.
