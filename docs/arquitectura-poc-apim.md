# Arquitectura – PoC APIM (k3s)

> **Entorno:** Nodo único `arqui.sandbox` · IP `172.16.14.185` · k3s sin Traefik
> **Productos evaluados:** Gravitee APIM · WSO2 APIM 4.6.0 · Kong Enterprise (pendiente)
> **Fecha:** 2026-03-24

---

## 1. Vista general

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                         HOST: arqui.sandbox (172.16.14.185)                 │
│                                                                              │
│  ┌──────────────────────────────────────────────────────────────────────┐   │
│  │                        k3s (single-node)                             │   │
│  │                                                                      │   │
│  │   ┌─────────────────────────────────────────────────────────────┐   │   │
│  │   │              NGINX Ingress Controller (NodePort)             │   │   │
│  │   │         :30080 (HTTP) · :30443 (HTTPS) · :31443 (HTTPS alt) │   │   │
│  │   └──────────┬────────────────────┬────────────────────┬────────┘   │   │
│  │              │ Host routing        │                    │            │   │
│  │   ┌──────────▼──────────┐ ┌───────▼──────────┐        │            │   │
│  │   │   apim-wso2         │ │   apim-gravitee   │   apim-kong         │   │
│  │   │   (namespace)       │ │   (namespace)     │   (pendiente)       │   │
│  │   └─────────────────────┘ └──────────────────┘                     │   │
│  │                                                                      │   │
│  │   ┌──────────────┐  ┌──────────────┐  ┌──────────────┐             │   │
│  │   │ poc-backends │  │  monitoring  │  │    vault     │             │   │
│  │   └──────────────┘  └──────────────┘  └──────────────┘             │   │
│  └──────────────────────────────────────────────────────────────────────┘   │
└─────────────────────────────────────────────────────────────────────────────┘

Clientes externos:
  PC/curl → 172.16.14.185:30443 → NGINX → APIM correspondiente según Host header
```

---

## 2. Namespaces

| Namespace | Propósito | Estado |
|---|---|---|
| `apim-wso2` | WSO2 APIM 4.6.0 + PostgreSQL | ✅ Operativo |
| `apim-gravitee` | Gravitee APIM + MongoDB + Elasticsearch | ✅ Operativo |
| `apim-kong` | Kong Enterprise | ⏳ Pendiente |
| `poc-backends` | Servicios backend de prueba (svc-fast, svc-slow, svc-error) | ✅ Operativo |
| `monitoring` | Prometheus + Grafana + Loki + OpenTelemetry | ✅ Operativo |
| `vault` | HashiCorp Vault (gestión de secretos) | ✅ Operativo |
| `cert-manager` | Gestión de certificados TLS | ✅ Operativo |
| `ingress-nginx` | NGINX Ingress Controller | ✅ Operativo |
| `poc-loadgen` | Generador de carga k6 | ✅ Operativo |
| `headlamp` | Dashboard Kubernetes UI | ✅ Operativo |

---

## 3. Capa de red y acceso externo

### 3.1 NGINX Ingress Controller

Punto de entrada único para todos los productos. Enruta por `Host` header.

```
NodePort          → Puerto interno  → Destino
:30080 (HTTP)     → 80              → Ingress rules (HTTP)
:30443 (HTTPS)    → 443             → Ingress rules (HTTPS) ← ESTÁNDAR
:31443 (HTTPS)    → 444             → Ingress rules (HTTPS) ← ALTERNATIVO
```

### 3.2 Hostnames y enrutamiento

| Hostname | Destino NGINX → | Backend service | Puerto pod |
|---|---|---|---|
| `apim-wso2.local` | → `wso2apim:9443` | WSO2 Management/Publisher/DevPortal | 9443 |
| `api-wso2.local` | → `wso2apim:8243` | WSO2 Gateway (HTTPS) | 8243 |
| `apim-gravitee.local` | → `gravitee-apim3-ui:8002` + `gravitee-apim3-api:83` | Gravitee UI + Management API | 8002/83 |
| `api-gravitee.local` | → `gravitee-apim3-gateway:82` | Gravitee Gateway | 82 |
| `portal-gravitee.local` | → `gravitee-apim3-portal:8003` | Gravitee Developer Portal | 8003 |

### 3.3 Configuración `/etc/hosts` requerida en clientes

```
172.16.14.185   apim-wso2.local
172.16.14.185   api-wso2.local
172.16.14.185   apim-gravitee.local
172.16.14.185   api-gravitee.local
172.16.14.185   portal-gravitee.local
```

---

## 4. Namespace: apim-wso2

### 4.1 Diagrama de componentes

```
apim-wso2 (namespace)
│
├── Deployment: wso2apim  (1 réplica, 2 containers)
│   ├── Container: vault-agent          ← gestiona renovación de secretos
│   └── Container: wso2apim            ← WSO2 APIM 4.6.0 all-in-one
│       ├── Publisher    :9443/publisher
│       ├── DevPortal    :9443/devportal
│       ├── Carbon       :9443/carbon
│       ├── Gateway HTTP :8280
│       └── Gateway HTTPS:8243
│
├── InitContainers (solo al arranque):
│   ├── vault-agent-init   ← obtiene secretos de Vault
│   └── render-config      ← renderiza deployment.toml con los secretos
│
├── Service: wso2apim (ClusterIP: 10.43.106.116)
│   ├── 9443  → pod:9443   (Management)
│   ├── 30443 → pod:9443   (Fix JWKS interno — ver sección 4.3)
│   ├── 8243  → pod:8243   (Gateway HTTPS)
│   └── 8280  → pod:8280   (Gateway HTTP)
│
├── Ingress: wso2apim        → apim-wso2.local  → service:9443
├── Ingress: wso2apim-gateway → api-wso2.local  → service:8243
│
├── Deployment: wso2-postgres (PostgreSQL 14)
│   ├── DB: wso2_shared_db
│   └── DB: wso2_apim_db
│
└── Secrets TLS:
    ├── wso2apim-tls         (cert para apim-wso2.local)
    └── wso2apim-gateway-tls (cert para api-wso2.local)
        → Ambos: cert autofirmado CN=apim-wso2.local, SAN=apim-wso2.local+api-wso2.local
```

### 4.2 Recursos del pod WSO2

| Recurso | Request | Limit |
|---|---|---|
| CPU | 2000m (2 cores) | 4000m (4 cores) |
| RAM | 4 Gi | 6 Gi |
| JVM heap | `-Xms2g -Xmx2g` | — |

### 4.3 Fix JWKS interno (decisión de diseño clave)

WSO2 valida los tokens JWT buscando el JWKS en la URL derivada del claim `iss` del token:
```
iss = https://apim-wso2.local:30443/oauth2/token
      → JWKS URL: https://apim-wso2.local:30443/oauth2/jwks
```

Para que esta resolución funcione **dentro del pod** sin pasar por NGINX (cuyo cert era inválido), se tomó la siguiente decisión:

```
hostAliases en el pod:
  apim-wso2.local → 10.43.106.116 (ClusterIP del service wso2apim)
  api-wso2.local  → 172.16.14.185 (IP del nodo, acceso externo vía NGINX)

Service wso2apim expone puerto 30443 → pod:9443

Flujo JWKS interno:
  WSO2 pod → apim-wso2.local:30443
           → 10.43.106.116:30443  (ClusterIP)
           → pod:9443             (WSO2 directo, sin NGINX)
           → cert propio de WSO2 (válido, CN=apim-wso2.local)
           → JWKS obtenido ✅
```

### 4.4 Gestión de secretos (Vault)

Los secretos se inyectan mediante el **Vault Agent Injector** en archivos dentro del pod:

| Archivo en pod | Secreto en Vault | Contenido |
|---|---|---|
| `/vault/secrets/admin` | `kv/apim/wso2/admin` | `admin_password=<valor>` |
| `/vault/secrets/db` | `kv/apim/wso2/db` | `<password>` |
| `/vault/secrets/keystore` | `kv/apim/wso2/keystore` | Keystore en base64 |
| `/vault/secrets/truststore` | `kv/apim/wso2/truststore` | Truststore en base64 |
| `/vault/secrets/keystore-password` | `kv/apim/wso2/keystore` | `<password>` |
| `/vault/secrets/truststore-password` | `kv/apim/wso2/truststore` | `<password>` |

El initContainer `render-config` toma estos archivos y genera `/config/repository/conf/deployment.toml` sustituyendo los placeholders `__ADMIN_PASSWORD__`, `__DB_PASSWORD__`, etc.

### 4.5 Flujo de arranque del pod

```
1. vault-agent-init  → obtiene secretos de Vault → escribe en /vault/secrets/
2. render-config     → lee /vault/secrets/* → genera deployment.toml → copia keystores
3. vault-agent       → sidecar, renueva tokens Vault
4. wso2apim          → arranca con deployment.toml ya renderizado
```

---

## 5. Namespace: apim-gravitee

### 5.1 Diagrama de componentes

```
apim-gravitee (namespace)
│
├── gravitee-apim3-api      (Management API)        ClusterIP :83
├── gravitee-apim3-gateway  (Gateway)               ClusterIP :82
├── gravitee-apim3-ui       (Management Console UI) ClusterIP :8002
├── gravitee-apim3-portal   (Developer Portal)      ClusterIP :8003
│
├── Elasticsearch (cluster de 5 pods):
│   ├── master-0   ← nodo master (1 de 2 requeridos para quórum)
│   ├── master-1   ← nodo master (necesario para quórum)
│   ├── data-0     ← nodo de datos
│   ├── ingest-0   ← nodo de ingesta
│   └── coordinating-0 ← nodo coordinador
│
├── MongoDB (1 pod, replicaset)   ClusterIP :27017
│
└── Ingress rules:
    ├── apim-gravitee.local   → ui:8002 + api:83
    ├── api-gravitee.local    → gateway:82
    └── portal-gravitee.local → portal:8003
```

### 5.2 Recursos por componente Gravitee

| Componente | Notas de sizing |
|---|---|
| Management API | Bajo consumo, stateless |
| Gateway | Bajo consumo en PoC (sin carga) |
| Elasticsearch master | **Mínimo 2 réplicas** para quórum (ver bug en hallazgos) |
| Elasticsearch data/ingest | 1 réplica cada uno |
| MongoDB | 1 réplica (replicaset de 1 nodo) |

### 5.3 Persistencia

Elasticsearch y MongoDB usan PersistentVolumeClaims. Los UUIDs de nodos Elasticsearch quedan registrados en la voting configuration. **Si se escala a 1 master, el cluster no puede arrancar.**

---

## 6. Namespace: poc-backends

Servicios backend de prueba usados durante la PoC:

| Service | ClusterIP | Puerto | Propósito |
|---|---|---|---|
| `svc-fast` | 10.43.1.97 | 80 | Respuesta rápida (~10ms) |
| `svc-slow` | 10.43.214.78 | 80 | Respuesta lenta (~2s) |
| `svc-error` | 10.43.244.17 | 80 | Simula errores HTTP 5xx |

**Backend real usado en la PoC:**
```
http://10.50.129.101:5511  ← ONP Thaqhiri API (externo al cluster)
Spec: http://10.50.129.101:5511/v3/api-docs
```

---

## 7. Infraestructura de seguridad

### 7.1 HashiCorp Vault

```
Namespace: vault
Pod: vault-0 (1/1 Running)
Acceso UI: http://172.16.14.185:32106

Estructura de secretos:
  kv/apim/wso2/
    ├── admin        → password del admin WSO2
    ├── db           → password de PostgreSQL
    ├── keystore     → archivo PKCS12 en base64 + password
    └── truststore   → archivo PKCS12 en base64 + password

  kv/apim/gravitee/
    └── admin        → password del admin Gravitee (si aplica)
```

El **Vault Agent Injector** (`vault-agent-injector`) intercepta la creación de pods con anotaciones `vault.hashicorp.com/*` e inyecta un sidecar que gestiona la obtención y renovación de secretos.

### 7.2 TLS / cert-manager

```
Namespace: cert-manager
ClusterIssuer: selfsigned-issuer (tipo: SelfSigned)

Estado actual:
- WSO2: Certificados TLS gestionados MANUALMENTE (cert-manager desactivado)
        → Cert autofirmado con openssl, Subject/SAN correctos
        → Secrets: wso2apim-tls, wso2apim-gateway-tls
        → Archivo para clientes: /home/arqui2/Descargas/wso2-apim-poc.crt

- Gravitee: Certificados TLS gestionados por cert-manager (selfsigned-issuer)
            → Subject/Issuer vacíos (comportamiento de selfsigned-issuer sin CN)
            → Clientes deben desactivar verificación SSL o importar el cert
```

---

## 8. Flujos de consumo de API

### 8.1 Flujo WSO2 – request completo

```
PC cliente
  │
  ├─ 1. Generar token APIM:
  │      POST https://apim-wso2.local:30443/oauth2/token
  │      grant_type=client_credentials
  │      → JWT (válido 1h, iss=https://apim-wso2.local:30443/oauth2/token)
  │
  └─ 2. Consumir API:
         GET https://api-wso2.local:30443/onpthaqhiriapi/1.0.0/api/horarios
         X-APIM-Authorization: Bearer <jwt-apim>
         Authorization: Bearer <token-saa>
              │
              ▼
         NGINX Ingress (:30443)
              │ Host: api-wso2.local → service wso2apim:8243
              ▼
         WSO2 Gateway (pod:8243)
              │
              ├─ Valida X-APIM-Authorization:
              │    JWT → obtiene iss → construye JWKS URL
              │    https://apim-wso2.local:30443/oauth2/jwks
              │    → resuelve a ClusterIP 10.43.106.116:30443
              │    → redirige a pod:9443 (WSO2 mismo)
              │    → obtiene JWKS → verifica firma JWT ✅
              │
              └─ Reenvía al backend:
                   GET http://10.50.129.101:5511/api/horarios
                   Authorization: Bearer <token-saa>  ← pasa directo
```

### 8.2 Flujo Gravitee – request completo

```
PC cliente
  │
  └─ Consumir API (sin paso previo de token):
       GET https://api-gravitee.local:30443/onpthaqhiriapi/api/horarios
       X-APIM-Authorization: 6bab1d02-6a3b-4eb1-ab1d-026a3bfeb1d1
       Authorization: Bearer <token-saa>
            │
            ▼
       NGINX Ingress (:30443)
            │ Host: api-gravitee.local → service gravitee-apim3-gateway:82
            ▼
       Gravitee Gateway (pod:82)
            │
            ├─ Valida X-APIM-Authorization:
            │    Busca API key en MongoDB → encontrada → suscripción ACCEPTED ✅
            │
            └─ Reenvía al backend:
                 GET http://10.50.129.101:5511/api/horarios
                 Authorization: Bearer <token-saa>  ← pasa directo
```

---

## 9. Observabilidad

| Componente | Namespace | Acceso |
|---|---|---|
| Prometheus | `monitoring` | Interno cluster |
| Grafana | `monitoring` | Via ingress (si configurado) |
| Loki | `monitoring` | Interno cluster |
| OpenTelemetry Collector | `monitoring` | Interno cluster |
| Alertmanager | `monitoring` | Interno cluster |

> Estado actual: stack desplegado pero **no conectado** a los APIMss. Pendiente configurar scraping de métricas de WSO2 y Gravitee como parte de los casos de prueba C1-C11.

---

## 10. Resumen de puertos expuestos al exterior

| Puerto | Protocolo | Servicio accesible |
|---|---|---|
| 30080 | HTTP | Todos los Ingress (sin TLS) |
| 30443 | HTTPS | Todos los Ingress (TLS) ← **uso estándar** |
| 31443 | HTTPS | Todos los Ingress (TLS) ← alternativo |
| 32106 | HTTP | Vault UI |
