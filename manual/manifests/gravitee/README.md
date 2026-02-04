# Gravitee APIM (manual)

YAMLs manuales para Gravitee APIM 4.10.3 (Mongo, sin ES).

Orden sugerido:
- `00-namespace.yaml`
- `05-mongo-pvc.yaml`
- `06-mongo-deployment.yaml`
- `07-mongo-service.yaml`
- `10-management-api-configmap.yaml`
- `11-management-api-deployment.yaml`
- `12-management-api-service.yaml`
- `20-gateway-configmap.yaml`
- `21-gateway-deployment.yaml`
- `22-gateway-service.yaml`
- `30-portal-deployment.yaml`
- `31-portal-service.yaml`
- `40-console-deployment.yaml`
- `41-console-service.yaml`
- `50-ingress-console.yaml`
- `51-ingress-portal.yaml`
- `52-ingress-gateway.yaml`

Aplicar:
```bash
kubectl apply -f manual/manifests/gravitee/
```

Notas:
- Analytics deshabilitado (sin Elasticsearch).
- Hostnames:
  - `apim-gravitee.local` (Console UI)
  - `portal-gravitee.local` (Dev Portal)
  - `api-gravitee.local` (Gateway)
