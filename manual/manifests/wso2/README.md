# WSO2 APIM (manual)

YAMLs manuales para WSO2 APIM 4.6.0.

Orden sugerido:
- `00-namespace.yaml`
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
- Revisar recursos (CPU/RAM) segun tu nodo.
