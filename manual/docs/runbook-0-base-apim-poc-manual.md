# Runbook 0 – Base común del PoC (k3s + NGINX + TLS + Observabilidad + Backends + k6)

## 0) Alcance y resultado esperado
Este runbook deja **lista la plataforma base** para ejecutar la PoC de APIM de forma comparable.  
Resultado esperado: entorno k3s operativo con Ingress, TLS, observabilidad, backends y k6 listos.

> Nota: Luego se instala **un APIM a la vez** (Gravitee → WSO2 → Kong Enterprise) para no sobrecargar la máquina (16 cores / 16 GB RAM).

---

## 1) Pre‑requisitos y registros

### 1.1) Baseline de infraestructura (registrar)

Guarda estas versiones en el kit de evidencias:
```bash
k3s --version
kubectl version --short
helm version
helm list -A
```

### 1.2) Kit de evidencias (crear estructura)

```bash
EVIDENCE_DATE=$(date +%F)
mkdir -p evidence/$EVIDENCE_DATE/{wso2,gravitee,kong}
```

Regla: todo cambio/ajuste debe registrarse en el kit con fecha y hora.

### 1.3) Documentación base (leer antes de ejecutar)
- `manual/checklist.md` (Zero Trust B2B/B2C)
- `manual/test.md` (APIs de ejemplo y baseline de seguridad)

### 1.4) Enfoque manual (sin Helm)
Todo se despliega con **YAMLs** y `kubectl apply`.

Ruta:
- `manual/manifests/<componente>/`

#### Qué busca este enfoque
- **Control total:** cada manifest es explícito.
- **Trazabilidad:** cambios directos en YAML.
- **Imparcialidad:** mismo flujo manual para cada APIM.

#### Qué ganamos
- Independencia de Helm/Charts.
- Diagnóstico más directo.

---

## 2) Pasos de ejecución (en orden)

## Paso 1) Preparar k3s (sin Traefik)

### A1) Instalar / Reinstalar k3s (recomendado para evitar conflictos)
```bash
sudo /usr/local/bin/k3s-uninstall.sh 2>/dev/null || true

curl -sfL https://get.k3s.io | sh -s - server   --disable traefik
```

Verifica:
```bash
kubectl get nodes -o wide
kubectl get pods -A
```

> Si no quieres reinstalar, se puede deshabilitar Traefik en k3s, pero la forma “limpia” para PoC es reinstalar sin Traefik.

---

## Paso 2) Instalar NGINX Ingress Controller (NodePort)

**Modo manual (YAML):** usar manifests en `manual/manifests/ingress/`.

Aplicar:
```bash
kubectl apply -f manual/manifests/ingress/
```

Verifica:
```bash
kubectl -n ingress-nginx get pods,svc
```

Toma nota del NodePort HTTPS:
```bash
kubectl -n ingress-nginx get svc ingress-nginx-controller   -o jsonpath='{.spec.ports[?(@.name=="https")].nodePort}'; echo
```

Registra IP y NodePort para evitar confusiones:
```bash
NODE_IP=$(hostname -I | awk '{print $1}')
HTTPS_NODEPORT=$(kubectl -n ingress-nginx get svc ingress-nginx-controller -o jsonpath='{.spec.ports[?(@.name=="https")].nodePort}')
echo "NODE_IP=$NODE_IP" && echo "HTTPS_NODEPORT=$HTTPS_NODEPORT"
```

> Escenario con WAAP: mantener NGINX Ingress detrás del WAAP para routing interno, TLS controlado y despliegues canary/blue-green.

---

## Paso 3) Dominio local vía `/etc/hosts`

Obtén la IP del nodo:
```bash
NODE_IP=$(hostname -I | awk '{print $1}')
echo $NODE_IP
```

Agrega en `/etc/hosts`:
```bash
sudo tee -a /etc/hosts >/dev/null <<EOF
$NODE_IP apim-wso2.local apim-gravitee.local apim-kong.local
$NODE_IP grafana.local prometheus.local loki.local
EOF
```

---

## Paso 4) TLS con cert-manager (self-signed)

**Modo manual (YAML):** usar manifests en `manual/manifests/base/`.
Versión actual del manifest: **cert-manager v1.19.3** (extraído del YAML descargado).

Aplicar cert-manager (CRDs + componentes):
```bash
kubectl apply -f manual/manifests/base/cert-manager/00-install.yaml
```

ClusterIssuer:
```bash
kubectl apply -f manual/manifests/base/cert-issuer.yaml
```

---

## Paso 5) Vault para secretos (obligatorio)

Usar Vault como **única fuente de secretos** (admin passwords, client secrets OIDC, licencias, etc.).  
No se permiten otros secret stores. Si se requiere secret en Kubernetes, debe **derivarse desde Vault** y quedar documentado en el kit de evidencias.

Checklist mínimo:
- Vault operativo (existente o nuevo).
- Auth de Kubernetes configurado en Vault.
- Policies y roles por namespace (apim-wso2 / apim-gravitee / apim-kong).

### Método estándar (PoC): Vault Agent Injector
Usar **Vault Agent Injector** (sidecar + templates) para inyectar secretos como archivos en los pods del APIM.

Regla: toda inyección debe quedar documentada en el `changes.log` con fecha/hora.

> Referencia rápida: `manual/vault/README.md`

### Cómo hacerlo (pasos mínimos)
1) **Usar Vault externo** (no se instala en este clúster):
```bash
```
Ver referencia: `manual/manifests/vault/EXTERNAL-VAULT.md`
```

2) **Habilitar auth de Kubernetes** y crear role:
```bash
vault auth enable kubernetes
vault write auth/kubernetes/config \\
  token_reviewer_jwt=\"<jwt>\" \\
  kubernetes_host=\"https://<k8s-api>\" \\
  kubernetes_ca_cert=@/var/run/secrets/kubernetes.io/serviceaccount/ca.crt

vault write auth/kubernetes/role/apim-gravitee \\
  bound_service_account_names=default \\
  bound_service_account_namespaces=apim-gravitee \\
  policies=apim-gravitee
```

3) **Crear policies y secretos**:
```bash
vault policy write apim-gravitee - <<'POL'
path "kv/apim/gravitee/*" { capabilities = ["read"] }
POL

vault kv put kv/apim/gravitee/admin password="changeme"
```

4) **Habilitar Vault Agent Injector** (si no está activo):
```bash
helm upgrade --install vault-agent-injector hashicorp/vault \\
  -n vault \\
  --set injector.enabled=true \\
  --set server.enabled=false
```

5) **Anotar deployments** del APIM con `vault.hashicorp.com/*` (ver runbooks 1–3).

> Ajustar service accounts, namespaces y paths reales según tu entorno.
> Si ya existe Vault corporativo, omite instalación/init y usa el endpoint provisto.

## Paso 6) Observabilidad (Prometheus + Grafana + Loki + OpenTelemetry Collector)

**Modo manual (YAML):** usar manifests en `manual/manifests/observability/`.

Aplicar (orden recomendado, **Prometheus Operator**):
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
kubectl apply -f manual/manifests/observability/otel-configmap.yaml
kubectl apply -f manual/manifests/observability/otel-deployment.yaml
kubectl apply -f manual/manifests/observability/otel-service.yaml
```

Nota: no aplicar `manual/manifests/observability/prometheus/` cuando se usa el operator.

> Luego afinamos los manifests del collector para exporters (Prometheus/OTLP/Loki/otros) según lo que exponga cada APIM.

---

## Paso 7) Exponer Grafana por Ingress (HTTPS)

1) Aplicar el Ingress manual:
```bash
kubectl apply -f manual/manifests/observability/grafana/ingress.yaml
```

2) Acceso por NodePort (alternativo):
- Grafana: `http://<node-ip>:30300`

---

## Paso 8) Backends de PoC (svc-fast / svc-slow / svc-error)

Crea namespace:
```bash
kubectl create ns poc-backends
```

### Manifests locales (recomendado)
```bash
kubectl apply -f manual/backends/00-namespace.yaml
kubectl apply -f manual/backends/10-app-configmap.yaml
kubectl apply -f manual/backends/20-svc-fast.yaml
kubectl apply -f manual/backends/30-svc-slow.yaml
kubectl apply -f manual/backends/40-svc-error.yaml
```

Verifica:
```bash
kubectl -n poc-backends get pods,svc
```

---

## Paso 9) LoadGen con k6 (desde dentro del clúster)

Crea namespace:
```bash
kubectl create ns poc-loadgen
```

Lanza un pod interactivo:
```bash
kubectl -n poc-loadgen run k6 --image=grafana/k6:latest -it --rm --restart=Never -- sh
```

Dentro del pod, valida conectividad al backend:
```sh
apk add --no-cache curl
curl -sS http://svc-fast.poc-backends.svc.cluster.local/ | head
```

> Los scripts k6 están versionados en `manual/k6/` (S0–S3). Ejecuta los escenarios con variables `BASE_URL`, `PATH`, `API_KEY` o `JWT` según corresponda.
> Puedes correr k6 desde el host (más simple) o copiar los scripts al pod (`kubectl cp`) si quieres ejecutar dentro del clúster.

Ejemplo (export JSON al kit):
```bash
EVIDENCE_DATE=$(date +%F)
k6 run manual/k6/s1-apikey.js -e BASE_URL=https://apim-wso2.local -e PATH=/fast -e API_KEY=XXXX \\
  --summary-export evidence/$EVIDENCE_DATE/wso2/round-1/k6/s1-apikey-summary.json
```

---

## Paso 10) Regla de operación (para 16 GB RAM)

Mantener siempre:
- `monitoring`
- `poc-backends`
- `poc-loadgen`

Levantar solo **uno** a la vez:
- `apim-gravitee` **o**
- `apim-wso2` **o**
- `apim-kong`

### Verificación de "Headroom" (Espacio libre)
Antes de instalar cualquier APIM, verifica cuánto espacio real queda:
```bash
kubectl top nodes
free -h
```
> Si `monitoring` consume más de 4-5 GB, considera reducir la retención de Loki o el scrape interval de Prometheus para dejar espacio al APIM.

---

## Siguiente paso
- **Runbook 1:** Gravitee APIM en k3s con NGINX + TLS + Portal + Smoke tests  
- **Runbook 2:** WSO2 APIM en k3s (all-in-one) con NGINX + TLS + Portal + Smoke tests  
- **Runbook 3:** Kong Enterprise + Developer Portal en k3s con NGINX + TLS (requiere licencia trial)

---

## Plantilla de segmentación B2B / B2C (para todos los APIM)

Objetivo: implementar **segmentación lógica** en cada producto de forma comparable.

**Segmentos**
- **B2B**: partners/empresas externas
- **B2C**: consumidores finales

**Planes sugeridos**
- **B2B-Partner**: cuotas propias, **OAuth2 client credentials**, acceso a APIs específicas
- **B2C-Public**: **OAuth2 authorization code**, scopes y refresh tokens

**Checklist mínimo**
- B2B: 1 empresa externa, 1 app, client credentials, rate limit propio, acceso solo a ciertas APIs
- B2C: usuarios finales, auth code, scopes, refresh tokens

**Evidencias mínimas**
- Capturas de planes/segmentos y configuración OAuth2
- Credenciales separadas por segmento
- Pruebas k6 diferenciadas: picos B2C vs steady B2B

**Preguntas post-ejecución**
- ¿Qué tan fácil fue?
- ¿Qué tan claro quedó para el partner?
- ¿Dónde duele operar?
