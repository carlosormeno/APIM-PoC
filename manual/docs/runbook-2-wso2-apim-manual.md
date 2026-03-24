# Runbook 2 – WSO2 APIM (k3s + NGINX + TLS + Portal + B2B/B2C)

> Objetivo: instalar y validar WSO2 APIM en el entorno base, aplicando el baseline de seguridad y los casos B2B/B2C definidos en `manual/test.md` y `manual/checklist.md`.

---

## 0) Pre-requisitos
- Base lista según `manual/docs/runbook-0-base-apim-poc-manual.md`.
- Ingress NGINX operativo + TLS (cert-manager).
- Vault disponible para secrets (obligatorio).
- Backends PoC desplegados en `poc-backends`.

---

## 1) Instalación de WSO2 APIM (Manual)

> Nota: usar **WSO2 APIM 4.6.0**. Registrar versión exacta de imágenes en evidencias.

1. Crear namespace:
```bash
kubectl create ns apim-wso2
```

2. Preparar manifests en `manual/manifests/wso2/`:
- PostgreSQL (2 DBs: `wso2_shared_db` y `wso2_apim_db`)
- Deployments/Services/Ingress
- Recursos (requests/limits)
- Admin creds desde Vault
- Persistence (si aplica)

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

Vault esperado:
- `kv/apim/wso2/db` (password para WSO2 DBs)
- `kv/apim/wso2/postgres` (password para Postgres)
- `kv/apim/wso2/admin` (admin_password)
- `kv/apim/wso2/keystore` (file_b64, password)
- `kv/apim/wso2/truststore` (file_b64, password)

4. Aplicar manifests:
```bash
kubectl apply -f manual/manifests/wso2/
```

5. Actualizar `/etc/hosts` con `api-wso2.local` (gateway).

6. Verificar:
```bash
kubectl -n apim-wso2 get pods,svc,ingress
```

> Post‑instalación: cuando el gateway tenga una API estable (`/health`), mover readiness/liveness probes a **8243**. Mantener `/services/Version` en 9443 solo durante instalación.

---

## 2) Configuración inicial
- Acceder a Publisher/Dev Portal.
- Crear usuario admin y roles base.
- Configurar el IdP/OIDC (para B2B/B2C) si aplica.

---

## 3) Publicación de APIs de ejemplo (no “hello world”)
Implementar todas las APIs de `manual/test.md`:

- `/partner/orders` (B2B)
- `/customer/profile` (B2C)
- `/legacy/billing`
- `/health`

> Usar backends en `poc-backends` y documentar endpoints reales.

### Variante valida en PoC: importacion desde Swagger remoto
Si ya tienes OpenAPI expuesto por backend (ejemplo):
- `http://10.50.129.101:5511/v3/api-docs`

En Publisher:
1. `Create API` -> `Import Open API` (URL remota)
2. Definir `Context` y `Version`
3. Ajustar endpoint backend (`Production`/`Sandbox`) a:
   - `http://10.50.129.101:5511`
4. Crear revision, desplegar en gateway `Default` y publicar.

### Caso especial: backend con token propio + token APIM
Si el backend exige su propio Bearer token ademas del token de APIM:

1. En `Runtime` cambiar `Authorization Header` a:
   - `X-APIM-Authorization`

2. Invocar API con dos headers:
   - `X-APIM-Authorization: Bearer <token_apim>`
   - `Authorization: Bearer <token_backend>`

3. Crear nueva revision y desplegar luego del cambio de Runtime.

Nota:
- `900902` indica que APIM no recibio credencial en el header esperado.
- `900901` indica token APIM invalido/expirado.

### Caso especial: DB APIM sin tablas despues de reinicio
Si luego de reiniciar WSO2 no ves APIs y la DB esta vacia (sin tablas):

1. Verificar si hay tablas en `wso2_apim_db`:
```bash
kubectl -n apim-wso2 exec -it deploy/wso2-postgres -- \
  psql -U wso2 -d wso2_apim_db -c "\dt"
```

2. Si no hay tablas, ejecutar los dbscripts oficiales (PostgreSQL):
```bash
# Shared DB
kubectl -n apim-wso2 exec -it deploy/wso2apim -- \
  cat /home/wso2carbon/wso2am-4.6.0/dbscripts/postgresql.sql \
| kubectl -n apim-wso2 exec -i deploy/wso2-postgres -- \
  psql -U wso2 -d wso2_shared_db -f /dev/stdin

# APIM DB
kubectl -n apim-wso2 exec -it deploy/wso2apim -- \
  cat /home/wso2carbon/wso2am-4.6.0/dbscripts/apimgt/postgresql.sql \
| kubectl -n apim-wso2 exec -i deploy/wso2-postgres -- \
  psql -U wso2 -d wso2_apim_db -f /dev/stdin
```

3. Reiniciar WSO2:
```bash
kubectl -n apim-wso2 rollout restart deploy wso2apim
```

### Regenerar token APIM por cURL (client_credentials)
Cuando expire el token APIM, se puede regenerar sin usar la UI:

1. Obtener `consumer key` y `consumer secret` de la aplicacion en Dev Portal.
2. Generar `Basic` en base64 y pedir token:

```bash
CK='CONSUMER_KEY'
CS='CONSUMER_SECRET'
B64=$(printf '%s:%s' "$CK" "$CS" | base64 -w0)

curl -k -X POST 'https://apim-wso2.local:30443/oauth2/token' \
  -H "Authorization: Basic $B64" \
  -H 'Content-Type: application/x-www-form-urlencoded' \
  -d 'grant_type=client_credentials'
```

3. Para extraer solo `access_token`:

```bash
TOKEN=$(curl -ks -X POST 'https://apim-wso2.local:30443/oauth2/token' \
  -H "Authorization: Basic $B64" \
  -H 'Content-Type: application/x-www-form-urlencoded' \
  -d 'grant_type=client_credentials' | jq -r '.access_token')

echo "$TOKEN"
```

Uso en invocacion:

```bash
-H "X-APIM-Authorization: Bearer $TOKEN"
```

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

> Hardening opcional: NetworkPolicies y/o mTLS interno. Documentar si se aplica.

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
