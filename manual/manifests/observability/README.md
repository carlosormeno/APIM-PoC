# Observabilidad (manual)

Stack manual: **Prometheus Operator** + Grafana + Loki + OTel Collector + Jaeger + Alertmanager.

Orden sugerido:
- `00-namespace.yaml`
- `prometheus-operator/bundle.yaml` (CRDs + operator)
- `prometheus-operator/prometheus.yaml` + `prometheus-operator/prometheus-service.yaml`
- `prometheus-operator/prometheus-rules.yaml`
- `prometheus-operator/servicemonitors/` (solo los que apliquen)
- `alertmanager/` (si se usa)
- `grafana/`
- `loki-configmap.yaml`, `loki-deployment.yaml`, `loki-service.yaml`
- `jaeger/`
- `otel-configmap.yaml`, `otel-deployment.yaml`, `otel-service.yaml`

Aplicar (ejemplo):
```bash
kubectl apply -f manual/manifests/observability/00-namespace.yaml
kubectl apply -f manual/manifests/observability/prometheus-operator/bundle.yaml
kubectl apply -f manual/manifests/observability/prometheus-operator/prometheus.yaml
kubectl apply -f manual/manifests/observability/prometheus-operator/prometheus-service.yaml
kubectl apply -f manual/manifests/observability/prometheus-operator/prometheus-rules.yaml
kubectl apply -f manual/manifests/observability/prometheus-operator/servicemonitors/
kubectl apply -f manual/manifests/observability/alertmanager/
kubectl apply -f manual/manifests/observability/grafana/
kubectl apply -f manual/manifests/observability/loki-configmap.yaml
kubectl apply -f manual/manifests/observability/loki-deployment.yaml
kubectl apply -f manual/manifests/observability/loki-service.yaml
kubectl apply -f manual/manifests/observability/jaeger/
kubectl apply -f manual/manifests/observability/otel-configmap.yaml
kubectl apply -f manual/manifests/observability/otel-deployment.yaml
kubectl apply -f manual/manifests/observability/otel-service.yaml
```

Nota: **no aplicar** `manual/manifests/observability/prometheus/` cuando se usa el operator.

Acceso OTLP desde otras PCs:
- El `Service` `otel-collector` queda publicado como `NodePort`.
- OTLP gRPC: `<node-ip>:30809`
- OTLP HTTP: `http://<node-ip>:31947`
- Si UFW está activo, abrir esos puertos antes de probar clientes externos.

Jaeger UI para trazas:
- `jaeger` corre en modo `all-in-one`, pensado para demo/pruebas.
- La UI queda publicada en `http://<node-ip>:30686`.
- Las trazas se almacenan en memoria; se pierden si el pod se reinicia.
- El OTel Collector exporta traces a `jaeger.monitoring.svc.cluster.local:4317`.
