# Runbook 0 – Base común del PoC (k3s + NGINX + TLS + Observabilidad + Backends + k6)

> **Objetivo:** dejar lista la plataforma base común para ejecutar una PoC comparable de **API Management** en un nodo único **on‑prem** con **k3s**, usando **NGINX Ingress**, **dominio local (/etc/hosts)**, **TLS con cert-manager** y observabilidad con **Prometheus + Grafana + Loki + OpenTelemetry Collector**.  
> **Nota:** Luego se instala **un APIM a la vez** (Gravitee → WSO2 → Kong Enterprise) para no sobrecargar la máquina (16 cores / 16 GB RAM).

---

## Baseline de infraestructura (registrar)

Guarda estas versiones en el kit de evidencias:
```bash
k3s --version
kubectl version --short
helm version
helm list -A
```

## Kit de evidencias (crear estructura)

```bash
EVIDENCE_DATE=$(date +%F)
mkdir -p evidence/$EVIDENCE_DATE/{wso2,gravitee,kong}
```

Regla: todo cambio/ajuste debe registrarse en el kit con fecha y hora.

## Documentación base (leer antes de ejecutar)
- `checklist.md` (Zero Trust B2B/B2C)
- `test.md` (APIs de ejemplo y baseline de seguridad)

## Enfoque híbrido (Helm + Manifests renderizados)
Usamos Helm para parametrizar y **renderizamos YAML estático** para versionado.

Ruta:
- `APIM/<producto>/values.yaml`
- `manifests/<producto>/rendered.yaml`

Guía completa: `manifests/README.md`

### Automatización (Makefile)
Si Helm está instalado, puedes renderizar con:
```bash
make render-gravitee
make render-wso2
make render-kong
```

## A) Preparar k3s (sin Traefik)

### A1) Reinstalar k3s (recomendado para evitar conflictos)
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

## B) Instalar NGINX Ingress Controller (NodePort)

```bash
helm repo add ingress-nginx https://kubernetes.github.io/ingress-nginx
helm repo update

kubectl create ns ingress-nginx

helm install ingress-nginx ingress-nginx/ingress-nginx   -n ingress-nginx   --set controller.service.type=NodePort
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

## C) Dominio local vía `/etc/hosts`

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

## D) TLS con cert-manager (self-signed)

### D1) Instalar cert-manager
```bash
helm repo add jetstack https://charts.jetstack.io
helm repo update

kubectl create ns cert-manager

helm install cert-manager jetstack/cert-manager   -n cert-manager   --set crds.enabled=true
```

### D2) ClusterIssuer self-signed
```bash
cat <<'YAML' | kubectl apply -f -
apiVersion: cert-manager.io/v1
kind: ClusterIssuer
metadata:
  name: selfsigned-issuer
spec:
  selfSigned: {}
YAML
```

---

## E) Vault para secretos (obligatorio)

Usar Vault como **única fuente de secretos** (admin passwords, client secrets OIDC, licencias, etc.).  
No se permiten otros secret stores. Si se requiere secret en Kubernetes, debe **derivarse desde Vault** y quedar documentado en el kit de evidencias.

Checklist mínimo:
- Vault operativo (existente o nuevo).
- Auth de Kubernetes configurado en Vault.
- Policies y roles por namespace (apim-wso2 / apim-gravitee / apim-kong).

### Método estándar (PoC): Vault Agent Injector
Usar **Vault Agent Injector** (sidecar + templates) para inyectar secretos como archivos en los pods del APIM.

Regla: toda inyección debe quedar documentada en el `changes.log` con fecha/hora.

> Si no hay Vault disponible, definir un plan temporal (y dejarlo documentado) para no bloquear la PoC.

## F) Observabilidad (Prometheus + Grafana + Loki + OpenTelemetry Collector)

Crea namespace:
```bash
kubectl create ns poc-observability
```

### E1) Prometheus + Grafana (kube-prometheus-stack)
```bash
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm repo update

helm install kps prometheus-community/kube-prometheus-stack   -n poc-observability
```

### E2) Loki (stack simple)
```bash
helm repo add grafana https://grafana.github.io/helm-charts
helm repo update

helm install loki grafana/loki-stack   -n poc-observability   --set grafana.enabled=false
```

### E3) OpenTelemetry Collector
```bash
helm repo add open-telemetry https://open-telemetry.github.io/opentelemetry-helm-charts
helm repo update

helm install otel open-telemetry/opentelemetry-collector   -n poc-observability
```

> Luego afinamos `values.yaml` del collector para exporters (Prometheus/OTLP/Loki/otros) según lo que exponga cada APIM.

---

## G) Exponer Grafana por Ingress (HTTPS)

1) Identifica el Service de Grafana:
```bash
kubectl -n poc-observability get svc | grep grafana
```

2) Crea un Ingress (ajusta `service.name` si difiere; comúnmente es `kps-grafana`):
```bash
cat <<'YAML' | kubectl apply -f -
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: grafana
  namespace: poc-observability
  annotations:
    cert-manager.io/cluster-issuer: selfsigned-issuer
spec:
  ingressClassName: nginx
  tls:
  - hosts:
    - grafana.local
    secretName: grafana-tls
  rules:
  - host: grafana.local
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: kps-grafana
            port:
              number: 80
YAML
```

3) Credenciales de Grafana:
```bash
kubectl -n poc-observability get secret kps-grafana   -o jsonpath='{.data.admin-password}' | base64 -d; echo
```

---

## H) Backends de PoC (svc-fast / svc-slow / svc-error)

Crea namespace:
```bash
kubectl create ns poc-backends
```

### Manifests locales (recomendado)
```bash
kubectl apply -f backends/00-namespace.yaml
kubectl apply -f backends/10-app-configmap.yaml
kubectl apply -f backends/20-svc-fast.yaml
kubectl apply -f backends/30-svc-slow.yaml
kubectl apply -f backends/40-svc-error.yaml
```

Verifica:
```bash
kubectl -n poc-backends get pods,svc
```

---

## I) LoadGen con k6 (desde dentro del clúster)

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

> Los scripts k6 están versionados en `k6/` (S0–S3). Ejecuta los escenarios con variables `BASE_URL`, `PATH`, `API_KEY` o `JWT` según corresponda.
> Puedes correr k6 desde el host (más simple) o copiar los scripts al pod (`kubectl cp`) si quieres ejecutar dentro del clúster.

Ejemplo (export JSON al kit):
```bash
EVIDENCE_DATE=$(date +%F)
k6 run k6/s1-apikey.js -e BASE_URL=https://apim-wso2.local -e PATH=/fast -e API_KEY=XXXX \\
  --summary-export evidence/$EVIDENCE_DATE/wso2/round-1/k6/s1-apikey-summary.json
```

---

## J) Regla de operación (para 16 GB RAM)

Mantener siempre:
- `poc-observability`
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
> Si `poc-observability` consume más de 4-5 GB, considera reducir la retención de Loki o el scrape interval de Prometheus para dejar espacio al APIM.

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
