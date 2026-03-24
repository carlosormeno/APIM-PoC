# Runbook 1 – Gravitee APIM (k3s + NGINX + TLS + Portal + B2B/B2C)

> Objetivo: instalar y validar Gravitee APIM en el entorno base, aplicando el baseline de seguridad y los casos B2B/B2C definidos en `manual/test.md` y `manual/checklist.md`.

---

## 0) Pre-requisitos
- Base lista según `manual/docs/runbook-0-base-apim-poc-manual.md`.
- Ingress NGINX operativo + TLS (cert-manager).
- Vault disponible para secrets (obligatorio).
- Backends PoC desplegados en `poc-backends`.

---

## 1) Instalación de Gravitee (Helm oficial, clean install)

> Nota: para esta PoC, se recomienda borrar todo lo previo de `apim-gravitee` y reinstalar con el chart oficial.

1. Verificar que `ingress-nginx` tenga HTTPS en NodePort `31443`:
```bash
kubectl -n ingress-nginx get svc ingress-nginx-controller -o jsonpath='{.spec.ports[?(@.name=="https")].nodePort}{"\n"}'
```

2. Borrar instalación Gravitee previa (no afecta otros namespaces):
```bash
kubectl delete ns apim-gravitee --wait=true
kubectl create ns apim-gravitee
```

3. Verificar `/etc/hosts`:
- `apim-gravitee.local`
- `portal-gravitee.local`
- `api-gravitee.local`

4. Usar valores oficiales adaptados en:
- `APIM/gravitee/values.yaml`

5. Instalar chart oficial:
```bash
helm repo add graviteeio https://helm.gravitee.io
helm repo update

helm upgrade --install gravitee graviteeio/apim3 \
  -n apim-gravitee \
  -f APIM/gravitee/values.yaml \
  --wait --timeout 15m
```

6. Verificar estado:
```bash
kubectl -n apim-gravitee get pods,svc,ingress
```

7. Validar bootstrap de Management API:
```bash
curl -skD- https://apim-gravitee.local:31443/management/v2/ui/bootstrap
```

8. Login inicial:
- URL: `https://apim-gravitee.local:31443/`
- Usuario: `admin`
- Password: `admin`

### Notas operativas para esta PoC
- Se reutiliza infraestructura ya instalada en el nodo:
  - `ingress-nginx`
  - `cert-manager` (issuer `selfsigned-issuer`)
  - observabilidad, Vault, backends, etc.
- El puerto `31443` se mantiene como punto de entrada HTTPS para Gravitee.
- WSO2 no se toca porque está en otro namespace (`apim-wso2`).

---

## 2) Configuración inicial
- Acceder a la consola Publisher/Portal.
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
Exportar JSON a `evidence/YYYY-MM-DD/gravitee/round-X/k6`.

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
