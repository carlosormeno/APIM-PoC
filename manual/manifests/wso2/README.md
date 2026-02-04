# WSO2 APIM (manual)

YAMLs manuales para WSO2 APIM 4.6.0.

Orden sugerido:
- `00-namespace.yaml`
- `05-postgres-configmap.yaml`
- `06-postgres-pvc.yaml`
- `07-postgres-deployment.yaml`
- `08-postgres-service.yaml`
- `10-configmap.yaml`
- `50-pvc.yaml` (si aplica)
- `20-deployment.yaml`
- `30-service.yaml`
- `40-ingress.yaml`

Aplicar:
```bash
kubectl apply -f manual/manifests/wso2/
```

Notas:
- Ajustar `deployment.toml` en `10-configmap.yaml`.
- PostgreSQL usa 2 DBs: `wso2_shared_db` y `wso2_apim_db`.
- Vault esperado:
  - `kv/apim/wso2/db` (password)
  - `kv/apim/wso2/postgres` (password)
  - `kv/apim/wso2/admin` (admin_password)
- Revisar recursos (CPU/RAM) segun tu nodo.
