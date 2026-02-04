# Backends PoC (svc-fast / svc-slow / svc-error)

## Aplicar
```bash
kubectl apply -f backends/00-namespace.yaml
kubectl apply -f backends/10-app-configmap.yaml
kubectl apply -f backends/20-svc-fast.yaml
kubectl apply -f backends/30-svc-slow.yaml
kubectl apply -f backends/40-svc-error.yaml
```

## URLs internas
- `http://svc-fast.poc-backends.svc.cluster.local/`
- `http://svc-slow.poc-backends.svc.cluster.local/?delay_ms=200`
- `http://svc-error.poc-backends.svc.cluster.local/`

## OpenAPI (por servicio)
- `http://svc-fast.poc-backends.svc.cluster.local/openapi.json`
- `http://svc-slow.poc-backends.svc.cluster.local/openapi.json`
- `http://svc-error.poc-backends.svc.cluster.local/openapi.json`

## Notas
- `svc-slow` permite `delay_ms` en query para variar latencia.
- `svc-error` devuelve código configurable vía env `ERROR_CODE`.
