# NGINX Ingress Controller (manual)

YAMLs manuales listos para NodePort.

Orden sugerido:
- `00-namespace.yaml`
- `10-serviceaccount.yaml`
- `20-clusterrole.yaml`
- `30-clusterrolebinding.yaml`
- `40-configmap.yaml`
- `50-deployment.yaml`
- `60-service.yaml`
- `70-ingressclass.yaml`

Aplicar:
```bash
kubectl apply -f manual/manifests/ingress/
```
