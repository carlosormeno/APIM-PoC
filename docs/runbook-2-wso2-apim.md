# Runbook 2 – WSO2 APIM (k3s + NGINX + TLS + Portal + B2B/B2C)

> Objetivo: instalar y validar WSO2 APIM en el entorno base, aplicando el baseline de seguridad y los casos B2B/B2C definidos en `test.md` y `checklist.md`.

---

## 0) Pre-requisitos
- Base lista según `runbook-0-base-apim-poc.md`.
- Ingress NGINX operativo + TLS (cert-manager).
- Vault disponible para secrets (obligatorio).
- Backends PoC desplegados en `poc-backends`.

---

## 1) Instalación de WSO2 APIM (Helm)

> Nota: usar **WSO2 APIM 4.6.0**. El chart oficial es el release `all-in-one-4.6.0-1`. Mantener el `values.yaml` oficial como base y aplicar overrides en `APIM/wso2/values.yaml`. Registrar versión exacta del chart e imágenes en evidencias.

1. Crear namespace:
```bash
kubectl create ns apim-wso2
```

2. Preparar overrides en `APIM/wso2/values.yaml` con:
- Ingress (host `apim-wso2.local`, TLS)
- Recursos (requests/limits)
- Admin creds desde Vault
- Persistence (si aplica)

Base oficial: `APIM/wso2/values.base.yaml`

3. Inyectar secretos con Vault Agent Injector:
   - Anotar los pods/deployments con `vault.hashicorp.com/*`
   - Montar archivos en una ruta conocida por el producto
   - Registrar en `changes.log`

Ejemplo de annotations (ajustar path/clave en Vault):
```
vault.hashicorp.com/agent-inject: "true"
vault.hashicorp.com/role: "apim-wso2"
vault.hashicorp.com/agent-inject-secret-admin: "kv/apim/wso2/admin"
vault.hashicorp.com/agent-inject-template-admin: |
  {{- with secret "kv/apim/wso2/admin" -}}
  admin_password={{ .Data.data.password }}
  {{- end -}}
```

Ruta sugerida para archivos inyectados: `/vault/secrets/` (verificar en el chart).

4. Renderizar manifests (Helm → YAML):
```bash
helm template wso2apim wso2/wso2am \
  -n apim-wso2 \
  -f APIM/wso2/values.base.yaml \
  -f APIM/wso2/values.yaml \
  > manifests/wso2/rendered.yaml
```

5. Aplicar manifests:
```bash
kubectl apply -f manifests/wso2/rendered.yaml
```

6. (Opcional) Instalar/actualizar con Helm:
```bash
helm repo add wso2 https://helm.wso2.com
helm repo update

helm upgrade --install wso2apim wso2/wso2am \
  -n apim-wso2 \
  -f APIM/wso2/values.base.yaml \
  -f APIM/wso2/values.yaml
```

7. Verificar:
```bash
kubectl -n apim-wso2 get pods,svc,ingress
```

---

## 2) Configuración inicial
- Acceder a Publisher/Dev Portal.
- Crear usuario admin y roles base.
- Configurar el IdP/OIDC (para B2B/B2C) si aplica.

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
Exportar JSON a `evidence/YYYY-MM-DD/wso2/round-X/k6`.

---

## 8) Evidencias obligatorias
- Capturas Publisher/Portal
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
