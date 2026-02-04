# Observabilidad (manual)

Stack manual: Prometheus + Grafana + Loki + OTel Collector.

Orden sugerido:
- `00-namespace.yaml`
- `prometheus/`
- `grafana/`
- `loki-configmap.yaml`, `loki-deployment.yaml`, `loki-service.yaml`
- `otel-configmap.yaml`, `otel-deployment.yaml`, `otel-service.yaml`

Aplicar (ejemplo):
```bash
kubectl apply -f manual/manifests/observability/00-namespace.yaml
kubectl apply -f manual/manifests/observability/prometheus/
kubectl apply -f manual/manifests/observability/grafana/
kubectl apply -f manual/manifests/observability/loki-configmap.yaml
kubectl apply -f manual/manifests/observability/loki-deployment.yaml
kubectl apply -f manual/manifests/observability/loki-service.yaml
kubectl apply -f manual/manifests/observability/otel-configmap.yaml
kubectl apply -f manual/manifests/observability/otel-deployment.yaml
kubectl apply -f manual/manifests/observability/otel-service.yaml
```
