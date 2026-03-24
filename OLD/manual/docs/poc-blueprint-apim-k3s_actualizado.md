# PoC Blueprint – Plataforma de Gestión de APIs (API Management) on-prem (k3s)

> **Propósito:** documento guía para ejecutar una PoC comparable entre **WSO2**, **Gravitee** y **Kong (Enterprise)** en un entorno **on-premise** con **k3s**, simulando que **solo existe el API Management** (incluye su gateway/runtime), para medir **funcionalidad, seguridad, performance, operación y observabilidad**.

---

## 0) Alcance y reglas del PoC

### Objetivo
Validar una **Plataforma de Gestión de APIs (API Management)** desplegada **on-prem (k3s)** que cubra:

- **Portal** + onboarding de desarrolladores
- **Publicación** de APIs (OpenAPI)
- **Suscripciones/credenciales**
- **Seguridad** (TLS, API Key, JWT/OIDC; opcional mTLS)
- **Políticas** (rate limit/quotas, CORS, IP allow/deny, headers)
- **Observabilidad** y analítica
- **Gobierno** (RBAC, auditoría)
- **Performance** y resiliencia

### Regla clave (para comparación justa)
Durante cada ronda de pruebas, el APIM bajo evaluación debe ser el **único punto de entrada** (Ingress/URL pública).  
Los backends quedan **internos** en el clúster.

---

## 1) Arquitectura de PoC (común a los 3)

### Namespaces sugeridos
- `apim-wso2` / `apim-gravitee` / `apim-kong` (uno por producto)
- `poc-backends`
- `poc-observability`
- `poc-loadgen`

### Backends (en `poc-backends`)
Levantar **3 servicios** (contenedores simples) con OpenAPI, usando **manifiestos locales fijos**:

1) `svc-fast` : responde rápido (200 OK)  
2) `svc-slow` : responde con delay (ej. 200ms y 1s configurables)  
3) `svc-error` : devuelve errores controlados (404/500)  

**Requisito:** todos con **OpenAPI** definido y estable (evitar manifiestos remotos).

> Sugerido: usar los manifests locales en `backends/` (incluye `/openapi.json` por servicio).

### Consideraciones B2B / B2C
La PoC debe evaluar escenarios para **clientes externos (B2B/B2C)**:

- **B2B:** integraciones entre empresas, mayor énfasis en contratos, mTLS, IP allow/deny, SLAs y cuotas por cliente.
- **B2C:** alto volumen, autenticación de usuarios finales, picos de tráfico y autoscaling.

**Casos de prueba adicionales (mínimos):**
- Onboarding de partner B2B con credenciales dedicadas y plan propio.
- Portal/DevX para terceros (autoservicio, términos, aprobación).
- Policies diferenciadas por segmento (B2B vs B2C).
- Pruebas de carga con patrones distintos (picos B2C, steady B2B).

### Baseline de seguridad (Zero Trust) — resumen operativo
Aplicar en todos los productos:
- **Perímetro (WAAP):** TLS 1.2+, OWASP Top 10, bot protection, rate limit global, inspección HTTPS, logging.
- **Canal seguro:** HTTPS en todos los saltos, preservación `X-Forwarded-For` y `X-Request-ID`.
- **Ingress:** solo tráfico desde WAAP, sanitización de headers, sin auth de negocio.
- **APIM:** autenticación obligatoria, deny-by-default, validación de scopes, rate limits, cuotas.
- **Backends:** mTLS opcional, validación de JWT (issuer/audience), network policies.

> Checklist completo en `checklist.md`.

### Observabilidad (en `poc-observability`)
- **Métricas:** Prometheus  
- **Dashboards:** Grafana  
- **Logs:** Loki  
- **Traces/Metrics/Logs pipeline:** OpenTelemetry Collector (OTel Collector)  

> Nota: Para PoC, mantener la observabilidad **siempre encendida** y ejecutar **un APIM a la vez** (ver sección de recursos).

### KPIs mínimos comunes (para comparación justa)
Definir y reportar **el mismo set de métricas** en los 3 productos:

- **Throughput:** RPS sostenido (k6 + Prometheus).
- **Latency:** p50/p95/p99 (k6 + métricas del APIM/gateway si existen).
- **Errores:** % 4xx/5xx y 429 (k6 + métricas del APIM/gateway).
- **Upstream latency:** tiempo hacia backend (si el APIM expone la métrica).
- **Uso de recursos:** CPU/RAM por pod (kube-state-metrics / Prometheus).
- **Estabilidad:** reinicios, OOM, throttling (kube-state-metrics / events).

> Regla: si un APIM no expone cierta métrica, reportar **“no disponible”** y usar la fuente común (k6 + Prometheus) para comparación mínima.

**Fuente mínima obligatoria por KPI**
- Throughput/Latency/Errores: **k6 summary export** (JSON).
- Recursos/estabilidad: **Prometheus** (kube-state-metrics + cAdvisor).
- Upstream latency y métricas propias: **APIM/Gateway** (si lo expone).

### Load Generator (en `poc-loadgen`)
- `k6` (ideal) o `hey`/`wrk`
- Ejecutar desde dentro del clúster para reducir ruido de red externa

---

## 2) Plataforma base (decisiones de esta PoC)

### Ingress Controller
- **Elegido:** NGINX Ingress Controller (no Traefik)

Recomendación: instalar k3s **sin Traefik** y luego instalar NGINX Ingress con Helm.

### Enfoque híbrido (Helm + Manifests renderizados)
Para asegurar reproducibilidad y trazabilidad:
- Mantener `values.yaml` por producto en `APIM/<producto>/values.yaml`
- Renderizar YAML estático con `helm template` en `manifests/<producto>/`
- Aplicar con `kubectl apply`

> Guía en `manifests/README.md`.

### Escenario con WAAP (ej. Fortinet) + API Protection
Aunque el WAAP tenga módulo de **API Protection**, se mantiene **Ingress** entre WAAP y APIM por:
- **Routing nativo en k8s** (Services/Pods).
- **Separación de cambios** (WAAP perimetral vs. cambios internos).
- **TLS interno controlado** (cert-manager).
- **Estrategias de despliegue** (blue/green, canary).

Flujo recomendado: **WAAP → Ingress → APIM → Backends**.

Diagrama lógico:
```
Internet
  |
[WAAP]
  |
[NGINX Ingress]
  |
[APIM Gateway]
  |
[Backends]
```

### Dominio local
- **Elegido:** dominio local vía `/etc/hosts` (ej. `apim-wso2.local`, `apim-gravitee.local`, `apim-kong.local`).

### Certificados (TLS)
Recomendación: usar `cert-manager` con un `ClusterIssuer` **self-signed** para tener HTTPS real en Ingress durante la PoC.

### Secretos y configuración sensible
Usar **HashiCorp Vault** como **única** fuente de secretos.  
No se permiten otros secret stores. Si se requiere secret en Kubernetes, debe **derivarse desde Vault** y quedar documentado en el kit de evidencias.

---

## 3) Recursos y estrategia de ejecución

### Recursos del host (PoC)
- **CPU:** 16 cores  
- **RAM:** 16 GB  
- **OS actual:** Ubuntu Server 22.04

### Regla de arquitectura final (recomendada)
**1 APIM + segmentación lógica** (patrón sano para producción):
- **Products**
- **Groups**
- **Subscriptions**
- **Namespaces / Paths**
- **Policies por API**

> Esto evita multiplicar gateways y facilita gobierno, costos y operación.

### Baseline de infraestructura (registrar en cada ejecución)
- **k3s:** versión exacta
- **Helm:** versión exacta
- **Charts base:** versiones de `ingress-nginx`, `cert-manager`, `kube-prometheus-stack`, `loki-stack`, `opentelemetry-collector`
- **APIM:** versión exacta + edición (CE/Enterprise)
- **Imagen/pod sizing:** requests/limits aplicados

**Versiones objetivo (PoC)**
- **Gravitee APIM:** 4.10.3
- **WSO2 APIM:** 4.6.0

### Perfil de recursos recomendado (para comparabilidad)
Presupuesto total sugerido por APIM (nodo 16C/16GB):
- **APIM activo:** 4–6 vCPU / 6–8 GiB (requests), 6–8 vCPU / 8–10 GiB (limits)
- **Observabilidad (fijo):** 2–3 vCPU / 3–4 GiB
- **Backends + loadgen:** 1 vCPU / 1–2 GiB

> Ajustar si el producto requiere más componentes; mantener **el mismo presupuesto** entre WSO2/Gravitee/Kong.

### Regla operativa para no sobrecargar
- Mantener siempre: `poc-observability`, `poc-backends`, `poc-loadgen`
- Levantar **solo uno**: `apim-wso2` **o** `apim-gravitee` **o** `apim-kong`

---

## 4) Plan de ejecución (10–15 días, adaptable)

### Checklist de smoke tests (antes de cada ronda)
- DNS/hosts y TLS OK (HTTPS responde con cert esperado)
- APIM UI (publisher/portal) accesible
- API publicada responde 200 (sin auth)
- API con auth responde 200 (si aplica)
- Métricas visibles en Grafana
- Logs visibles en Loki
- k6 puede ejecutar un test corto (1–2 min)

### Ronda 1 – “Funciona como APIM” (por producto)
**Meta:** portal + publicación + consumo + baseline performance.

1. Despliegue APIM (all-in-one / CE / Enterprise)  
2. Exposición por Ingress (HTTPS)  
3. Publicar 1 API (OpenAPI) apuntando a `svc-fast`  
4. Portal: registrar developer → crear app → obtener credencial  
5. Consumir API vía credencial (API Key mínimo)  
6. Baseline performance sin auth y con API Key (2 tests)  

### Ronda 2 – “Seguridad y control” (por producto)
**Meta:** OIDC/JWT, rate limiting, políticas.

7. Integrar JWT/OIDC (ideal con IdP real; alternativo: JWT estático)  
8. Rate limit + quota por app/plan (dos planes: Free y Premium)  
9. IP allow/deny + CORS + headers  
10. Pruebas de carga con JWT y con rate limit activo  

### Ronda 3 – “Operación y resiliencia” (por producto)
**Meta:** RBAC, auditoría, fallas, HA básica.

11. RBAC (roles: Admin, Publisher, Viewer/Auditor)  
12. Auditoría: evidencia de “quién cambió qué”  
13. Resiliencia: backend lento/down, timeouts, retries (si aplica)  
14. HA mínima: 2 réplicas y prueba de rolling restart sin downtime (si aplica)  
15. Backup/restore de configuración (o export/import) como evidencia operativa  

---

## 5) Casos de prueba comparables (checklist + evidencia)

> En cada caso, capturar **evidencia**: captura de pantalla del portal/consola, logs, y métricas (Grafana).

### C1. Publicación de API (OpenAPI)
**Pasos**
- Importar OpenAPI  
- Publicar API v1  
- Ver en Portal  

**Criterio de aceptación**
- API visible en portal y consumible a través del endpoint del APIM

**Evidencia**
- Captura del API en publisher  
- Captura en portal  
- Curl/resultado 200 OK  

---

### C2. Onboarding developer + App + Credenciales
**Pasos**
- Crear usuario developer  
- Crear app  
- Obtener API Key (o client credentials)  

**Criterio**
- Dev obtiene credenciales sin intervención admin (o con el workflow definido)

**Evidencia**
- Captura app/credenciales  
- Curl con credencial válida (200)  
- Curl sin credencial (401/403)  

---

### C3. Planes/Suscripciones (Free vs Premium)
**Pasos**
- Definir 2 planes:  
  - Free: 10 rps y 1,000 req/día  
  - Premium: 50 rps y 10,000 req/día  
- Suscribir app a plan  

**Criterio**
- Free se limita y Premium no (en el mismo escenario de carga)

**Evidencia**
- Configuración de planes  
- Test de carga mostrando 429 (limit) en Free  
- Gráficas comparativas de tasa de error/429  

---

### C4. Seguridad JWT/OIDC
**Pasos**
- Validación JWT (ideal con IdP real; alternativo: JWT estático)  
- Requerir scope/claim  

**Criterio**
- Token válido y con scope → 200  
- Token válido sin scope → 403  
- Token inválido → 401  

**Evidencia**
- Config del policy  
- Curl de los 3 casos  
- Métricas 401/403  

---

### C5. TLS (y opcional mTLS)
**Pasos**
- Exponer solo HTTPS  
- Rotar certificado (si se puede en PoC)  
- (Opcional) mTLS por ruta  

**Criterio**
- HTTP bloqueado/redirigido  
- HTTPS OK  
- (mTLS) sin cert cliente → fail, con cert → OK  

**Evidencia**
- Ingress/TLS config  
- Curl -vk resultados  

---

### C6. Políticas adicionales
**Pasos**
- CORS permitido para dominio X  
- Header transform (agregar X-Request-ID)  
- IP allow/deny  

**Criterio**
- Políticas aplican de forma reproducible

**Evidencia**
- Capturas config  
- Curl mostrando headers/CORS  
- Logs con request-id  

---

### C7. Observabilidad y analítica
**Pasos**
- Dashboard mínimo (Grafana):
  - RPS  
  - p95/p99 latency  
  - 4xx/5xx  
  - Upstream latency  
  - Top APIs / Top Apps (si existe analítica propia)  

**Criterio**
- Métricas disponibles y atribuibles a API/app

**Evidencia**
- Capturas Grafana  
- Si el APIM trae analítica propia: captura “Top consumers”  
- Logs en Loki con correlación (ideal: request-id / trace-id)

---

### C8. Resiliencia (slow/down)
**Pasos**
- Apuntar a `svc-slow` con 200ms/1s  
- Apagar `svc-fast` para simular caída  
- Probar timeouts/retries (si aplica)  

**Criterio**
- Se observan timeout/5xx controlados, sin colapsar el APIM  
- (Opcional) circuit breaker si el producto lo soporta

**Evidencia**
- Gráficas de latencia p95/p99  
- Logs de timeout  
- Error rate controlado  

---

### C9. Gobierno: RBAC + Auditoría
**Pasos**
- Crear roles y usuarios  
- Probar permisos:  
  - viewer no publica  
  - publisher publica  
  - admin cambia políticas  
- Ver auditoría de cambios  

**Criterio**
- Permisos aplican y hay traza de cambios

**Evidencia**
- Capturas roles  
- Evento de auditoría con usuario+hora  

---

### C10. Operación: export/import o backup/restore
**Pasos**
- Exportar configuración API/policies  
- Reinstalar en limpio (o en namespace nuevo)  
- Importar y validar  

**Criterio**
- Reproducibilidad (APIOps)

**Evidencia**
- Artefacto exportado (YAML/JSON)  
- API funcional tras import  

---

### C11. B2B / B2C (segmentación externa realista)
**Regla:** evitar “hello world”. Usar flujos reales de autenticación y límites por segmento.

**Caso B2B (partner externo)**
- 1 empresa externa  
- 1 app  
- **OAuth2 client credentials**  
- **Rate limit propio**  
- Acceso **solo a ciertas APIs**  

**Caso B2C (app móvil)**
- Usuarios finales  
- **OAuth2 authorization code**  
- **Scopes**  
- **Refresh tokens**  

**Pasos**
- Definir 2 segmentos: **B2B** y **B2C**  
- Crear 2 planes distintos con políticas explícitas  
- Onboarding del partner B2B con credenciales dedicadas  
- Configurar flujos OAuth2 correspondientes  

**Criterio**
- B2B y B2C tienen políticas/planes diferentes y medibles  
- Accesos restringidos por API/segmento  
- Flujos OAuth2 funcionan end-to-end  

**Evidencia**
- Capturas de planes/segmentos  
- Capturas de configuración OAuth2  
- Curl/requests de ambos casos  
- Pruebas de carga diferenciadas (picos B2C vs steady B2B)  

**Preguntas clave (post-ejecución)**
- ¿Qué tan fácil fue?  
- ¿Qué tan claro quedó para el partner?  
- ¿Dónde duele operar?  

---

## 5.1) APIs de ejemplo (para escenarios reales)
Implementar estas APIs en cada APIM (no usar “hello world”):

- **B2B – Partner Orders API** (`/partner/orders`)
  - OAuth2 **Client Credentials**
  - Rate limit por partner
  - Quota mensual
  - Validación de esquema JSON
  - Acceso restringido por scope

- **B2C – Customer Profile API** (`/customer/profile`)
  - OAuth2 **Authorization Code**
  - Tokens por usuario
  - Scopes `profile.read`, `profile.update`
  - Rate limit por usuario

- **Legacy – Billing API** (`/legacy/billing`)
  - Transformación request/response
  - Traducción auth (API Key → OAuth)
  - Throttling agresivo

- **Interna – Health API** (`/health`)
  - Acceso solo interno

> Detalle completo en `test.md`.

## 6) Pruebas de performance (k6) — estándar para los 3

### Escenarios
- **S0 Baseline (sin auth)**: 5m warmup + 10m steady  
- **S1 API Key**: igual carga  
- **S2 JWT**: igual carga  
- **S3 Rate limit**: carga por encima del límite  

### Cargas sugeridas (ajustables)
- 50 RPS, 200 RPS, 500 RPS (3 niveles)

### KPIs a reportar
- p50/p95/p99 latency  
- throughput sostenido  
- error rate (4xx/5xx) y 429 por limit  
- CPU/RAM por pod (APIM y gateway)  
- reinicios, OOM, throttling  

**Evidencia**
- Export de k6 (JSON) + capturas de Grafana

> Scripts versionados en `k6/` para S0–S3 (mismos endpoints, headers y umbrales).

---

## 7) Matriz de scoring (para decisión “comprable”)

### Puntajes (0–5 por ítem)
**A. Funcional (40%)**
- Portal completo  
- Suscripciones/planes  
- Lifecycle (v1/v2, deprecación)  
- Seguridad (API key, JWT/OIDC, TLS)  

**B. Operación (35%)**
- HA/escala  
- Auditoría y RBAC  
- Backup/export/import  
- Observabilidad (Prom/Grafana/Loki/OTel)  

**C. Integración (15%)**
- IdP (OIDC)  
- CI/CD/APIOps  
- Integración con Prometheus/Loki/OTel  

**D. Esfuerzo/TCO (10%)**
- Tiempo de instalación  
- Nº componentes  
- Complejidad de upgrades  
- Consumo de recursos  

---

## 8) Resultados y entregables (para tu informe)
1) **Cuadro comparativo** con scoring  
2) **Evidencias** (capturas + logs + métricas)  
3) **Riesgos y mitigaciones** (por producto)  
4) **Recomendación final** (con criterios genéricos)  
5) **Requerimientos genéricos para compra (EETT)**:  
   - Funcionales  
   - No funcionales  
   - Seguridad/compliance  
   - Observabilidad  
   - Operación y soporte  
   - Criterios de aceptación  

### Kit de evidencias (estructura sugerida)
Organizar todo en una carpeta única por producto y ronda:

```\n+evidence/\n+  2026-01-29/\n+    wso2/\n+      round-1/\n+        screenshots/\n+        k6/\n+        grafana/\n+        logs/\n+      round-2/\n+      round-3/\n+    gravitee/\n+    kong/\n+```\n+
> Incluir: export JSON de k6, dashboards exportados de Grafana, capturas, y logs relevantes.

### Regla de documentación estricta
- Todo ajuste/cambio debe documentarse en el kit de evidencias.
- Registrar **fecha y hora**, motivo, impacto y responsable.
- Mantener un `changes.log` por producto y por ronda.

---

## 9) Nota específica sobre Kong (comparación justa)
Para que Kong compita como **APIM completo** en tu PoC **on-prem + portal**, debes usar **Kong Enterprise + Developer Portal**.  
Si solo usas Kong OSS, estarías probando un **gateway**, no un “manager completo”.

---

## 10) Parámetros confirmados (para el runbook)
- **Ingress:** NGINX Ingress Controller  
- **Dominio:** local vía `/etc/hosts` (ej. `apim-*.local`)  
- **Observabilidad:** Loki + OpenTelemetry Collector (además de Prometheus + Grafana)  
- **Recursos host:** 16 cores / 16 GB RAM  
- **Ejecución:** un APIM a la vez (WSO2 / Gravitee / Kong)  
- **Red:** documentar IP del nodo y NodePort HTTPS de cada APIM

---

**Fin del documento**
