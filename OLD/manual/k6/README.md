# k6 scripts (S0–S3)

## Variables comunes
- `BASE_URL` (obligatorio): endpoint del APIM, ej. `https://apim-wso2.local`.
- `PATH` (default: `/`): ruta publicada del API.
- `RPS` (default: 50)
- `WARMUP` (default: `5m`)
- `STEADY` (default: `10m`)
- `PRE_VUS` (default: 50)
- `MAX_VUS` (default: 200)

## Auth
- API Key: `API_KEY` y `API_KEY_HEADER` (default: `x-api-key`)
- JWT: `JWT`, `JWT_HEADER` (default: `Authorization`), `JWT_PREFIX` (default: `Bearer `)

## Ejemplos
```bash
k6 run k6/s0-baseline.js -e BASE_URL=https://apim-wso2.local -e PATH=/fast
k6 run k6/s1-apikey.js -e BASE_URL=https://apim-wso2.local -e PATH=/fast -e API_KEY=XXXX
k6 run k6/s2-jwt.js -e BASE_URL=https://apim-wso2.local -e PATH=/fast -e JWT=YYYY
k6 run k6/s3-ratelimit.js -e BASE_URL=https://apim-wso2.local -e PATH=/fast -e API_KEY=XXXX -e RPS=200 -e WARMUP=2m -e STEADY=5m
```

Si usas TLS self-signed:
```bash
k6 run k6/s0-baseline.js -e BASE_URL=https://apim-wso2.local -e PATH=/fast --insecure-skip-tls-verify
```

## Salidas
Recomendado: exportar JSON para el kit de evidencias.
```bash
k6 run k6/s1-apikey.js -e BASE_URL=... -e PATH=/fast --summary-export evidence/.../k6/s1-apikey-summary.json
```
