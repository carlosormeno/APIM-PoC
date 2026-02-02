# Runbook 3 – Kong Enterprise + Developer Portal (k3s + NGINX + TLS + B2B/B2C)

> Objetivo: instalar y validar Kong Enterprise + Developer Portal en el entorno base, aplicando el baseline de seguridad y los casos B2B/B2C definidos en `test.md` y `checklist.md`.

---

## 0) Pre-requisitos
- Base lista según `runbook-0-base-apim-poc.md`.
- Ingress NGINX operativo + TLS (cert-manager).
- Vault disponible para secrets (licencia, admin, OIDC).
- Backends PoC desplegados en `poc-backends`.

---

## 1) Instalación de Kong Enterprise (Helm)

> Nota: fijar versión exacta del chart e imágenes en `values.yaml` y registrarlo en evidencias.

1. Crear namespace:
```bash
kubectl create ns apim-kong
```

2. Preparar `values.yaml` con:
- Ingress (host `apim-kong.local`, TLS)
- Recursos (requests/limits)
- Licencia desde Vault
- Portal habilitado

3. Inyectar secretos con Vault Agent Injector:
   - Anotar los pods/deployments con `vault.hashicorp.com/*`
   - Montar archivos en una ruta conocida por el producto
   - Registrar en `changes.log`

Ejemplo de annotations (ajustar path/clave en Vault):
```
vault.hashicorp.com/agent-inject: "true"
vault.hashicorp.com/role: "apim-kong"
vault.hashicorp.com/agent-inject-secret-license: "kv/apim/kong/license"
vault.hashicorp.com/agent-inject-template-license: |
  {{- with secret "kv/apim/kong/license" -}}
  license={{ .Data.data.license }}
  {{- end -}}
```

Ruta sugerida para archivos inyectados: `/vault/secrets/` (verificar en el chart).

4. Renderizar manifests (Helm → YAML):
```bash
helm template kong kong/kong \
  -n apim-kong \
  -f APIM/kong/values.yaml \
  > manifests/kong/rendered.yaml
```

5. Aplicar manifests:
```bash
kubectl apply -f manifests/kong/rendered.yaml
```

6. (Opcional) Instalar/actualizar con Helm:
```bash
helm repo add kong https://charts.konghq.com
helm repo update

helm upgrade --install kong kong/kong \
  -n apim-kong \
  -f APIM/kong/values.yaml
```

7. Verificar:
```bash
kubectl -n apim-kong get pods,svc,ingress
```

---

## 2) Configuración inicial
- Acceder a Manager/Developer Portal.
- Cargar licencia Enterprise.
- Configurar IdP/OIDC (para B2B/B2C) si aplica.

---

## 3) Publicación de APIs de ejemplo (no “hello world”)
Implementar todas las APIs de `test.md`:

- `/partner/orders` (B2B)
- `/customer/profile` (B2C)
- `/legacy/billing`
- `/health`

> Usar backends en `poc-backends` y documentar endpoints reales.

---

## 4) Segmentación B2B/B2C (obligatorio)

### B2B – Partner externo
- 1 empresa externa
- 1 app
- OAuth2 **client credentials**
- Rate limit propio
- Acceso solo a ciertas APIs

### B2C – App móvil
- Usuarios finales
- OAuth2 **authorization code**
- Scopes
- Refresh tokens

> Registra en evidencias el flujo completo (capturas + requests + tokens).

---

## 5) Policies mínimas
- Auth obligatorio (deny-by-default)
- Validación de scopes
- Rate limits y quotas por plan
- IP allow/deny (si aplica)
- CORS + headers (X-Request-ID)

---

## 6) Smoke tests
Ver checklist en `poc-blueprint-apim-k3s_actualizado.md`.

---

## 7) Performance (k6)
Ejecutar S0–S3 desde `k6/`.
Exportar JSON a `evidence/YYYY-MM-DD/kong/round-X/k6`.

---

## 8) Evidencias obligatorias
- Capturas Manager/Portal
- Config OAuth2
- Resultados k6
- Dashboards Grafana
- Logs relevantes
- `changes.log` actualizado

---

## 9) Preguntas post-ejecución
- ¿Qué tan fácil fue?
- ¿Qué tan claro quedó para el partner?
- ¿Dónde duele operar?
