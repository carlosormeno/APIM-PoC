# Hallazgos, Fixes y Estado Actual – PoC APIM

> **Propósito:** Registrar los bugs encontrados, las causas raíz, los fixes aplicados y el estado operativo actual de cada producto durante la ejecución de la PoC. Sirve como base para el documento técnico y funcional definitivo.
>
> **Entorno:** k3s (single-node) + NGINX Ingress + Vault + cert-manager
> **Productos evaluados:** Gravitee APIM 4.x · WSO2 APIM 4.6.0
> **Fecha de inicio:** 2026-03-24

---

## Índice

1. [Infraestructura común](#1-infraestructura-común)
2. [Gravitee APIM](#2-gravitee-apim)
3. [WSO2 APIM](#3-wso2-apim)
4. [Referencia rápida de consumo](#4-referencia-rápida-de-consumo)
5. [Pendientes y mejoras identificadas](#5-pendientes-y-mejoras-identificadas)

---

## 1. Infraestructura común

### 1.1 TLS – Certificados autofirmados sin Subject/Issuer

**Síntoma**
Los certificados TLS generados por cert-manager con `selfsigned-issuer` tenían los campos `Subject` e `Issuer` vacíos. Clientes como Insomnia, Thunder Client o Apache HttpClient (Java) rechazaban la conexión o fallaban en el parsing del certificado.

**Causa raíz**
El `ClusterIssuer` de tipo `selfsigned` en cert-manager genera certificados mínimos donde el Subject se deriva del CSR. Sin una configuración explícita de CN/SAN, el Subject queda vacío, lo que viola expectativas de varios parsers TLS.

**Fix aplicado**
Se eliminaron los recursos `Certificate` gestionados por cert-manager para los dominios WSO2:

```bash
kubectl delete certificate wso2apim-tls wso2apim-gateway-tls -n apim-wso2
```

Se generó un certificado autofirmado con Subject y SAN correctos (válido 10 años):

```bash
openssl req -x509 -newkey rsa:2048 -nodes \
  -keyout wso2-selfsigned.key \
  -out wso2-selfsigned.crt \
  -days 3650 \
  -subj "/C=PE/ST=Lima/L=Lima/O=WSO2-PoC/CN=apim-wso2.local" \
  -addext "subjectAltName=DNS:apim-wso2.local,DNS:api-wso2.local"
```

Se aplicó a los dos secrets TLS de WSO2:

```bash
kubectl create secret tls wso2apim-tls \
  --cert=wso2-selfsigned.crt --key=wso2-selfsigned.key \
  -n apim-wso2 --dry-run=client -o yaml | kubectl apply -f -

kubectl create secret tls wso2apim-gateway-tls \
  --cert=wso2-selfsigned.crt --key=wso2-selfsigned.key \
  -n apim-wso2 --dry-run=client -o yaml | kubectl apply -f -
```

Se eliminó la anotación `cert-manager.io/cluster-issuer` de los Ingress para que cert-manager no sobreescriba los secrets:
→ [40-ingress.yaml](../manual/manifests/wso2/40-ingress.yaml)
→ [41-ingress-gateway.yaml](../manual/manifests/wso2/41-ingress-gateway.yaml)

**Certificado resultante**
```
Subject: C=PE, ST=Lima, L=Lima, O=WSO2-PoC, CN=apim-wso2.local
Issuer:  C=PE, ST=Lima, L=Lima, O=WSO2-PoC, CN=apim-wso2.local
SAN:     DNS:apim-wso2.local, DNS:api-wso2.local
Válido hasta: 2036-03-21
```

**Archivo para clientes externos**
`/home/arqui2/Descargas/wso2-apim-poc.crt`
Importar en cada equipo que consuma la API para evitar errores SSL.

**Instalación en Linux:**
```bash
sudo cp wso2-apim-poc.crt /usr/local/share/ca-certificates/
sudo update-ca-certificates
```

**Nota sobre puertos**
NGINX Ingress expone dos puertos HTTPS:

| NodePort | Mapeo | Uso |
|---|---|---|
| 30443 | 443 → 30443 | Puerto estándar — WSO2 y Gravitee |
| 31443 | 444 → 31443 | Puerto alternativo (ambos funcionan) |

El enrutamiento se hace por hostname, no por puerto. Ambos productos usan **30443** como referencia.

---

## 2. Gravitee APIM

### 2.1 Credenciales de acceso

| Consola | URL | Usuario | Contraseña |
|---|---|---|---|
| Management UI | `https://apim-gravitee.local:30443` | `admin` | `admin` |
| Developer Portal | `https://portal-gravitee.local:30443` | `admin` | `admin` |
| Gateway | `https://api-gravitee.local:30443` | — | — |

### 2.2 Bug: Elasticsearch en CrashLoopBackOff (~6000 reinicios)

**Síntoma**
El pod `graviteeio-apim-elasticsearch-master-0` acumuló ~6000 reinicios. Los pods `gravitee-apim3-api`, coordinating, data e ingest también fallaban en cascada.

**Causa raíz**
El cluster de Elasticsearch fue bootstrapped con 2 nodos master (`master-0` y `master-1`), cuyos UUIDs quedaron registrados en la voting configuration. Al escalar el StatefulSet a 1 réplica (solo `master-0`), el cluster no podía alcanzar quórum porque esperaba a `master-1` para elegir líder. Sin quórum, Elasticsearch no arranca → CrashLoopBackOff.

**Fix aplicado**

```bash
# Restaurar la segunda réplica
kubectl scale statefulset graviteeio-apim-elasticsearch-master \
  --replicas=2 -n apim-gravitee

# Forzar reinicio de master-0 para resetear el timer de CrashLoopBackOff
kubectl delete pod graviteeio-apim-elasticsearch-master-0 -n apim-gravitee
```

Ambos masters se descubrieron, `master-1` fue elegido líder y el cluster quedó verde.

**Resultado**
Todos los pods de Elasticsearch y `gravitee-apim3-api` pasaron a `1/1 Running`.

**Lección aprendida**
En entornos de recursos limitados (PoC), un cluster Elasticsearch de 2 nodos master es frágil. Si se va a usar un solo nodo en producción o staging, se debe configurar desde el inicio con `discovery.type: single-node` o `cluster.initial_master_nodes` apuntando solo al nodo único.

### 2.3 Configuración del API ONP Thaqhiri

**Estado:** Operativo ✅

El API fue importado desde la especificación OpenAPI del backend:
```
http://10.50.129.101:5511/v3/api-docs
```

**Configuración resultante:**

| Parámetro | Valor |
|---|---|
| Nombre | ONP Thaqhiri API |
| Context path | `/onpthaqhiriapi/` |
| Backend | `http://10.50.129.101:5511` |
| Estado | STARTED / DEPLOYED |
| Plan | APIM Key (API_KEY) |
| Header autenticación | `X-APIM-Authorization` |
| Propagación de key al backend | Desactivada |

**Ajustes realizados sobre la configuración inicial:**

1. **Header del plan cambiado** de `X-Gravitee-Api-Key` a `X-APIM-Authorization` para alinear con el estándar definido en la PoC.

2. **Propagación de API key desactivada** (`propagateApiKey: false`) para que la key de Gravitee no llegue al backend.

3. **Política Transform Headers eliminada** del flow. La política original transformaba el header `X-Backend-Token` en `Authorization: Bearer {valor}`, lo que sobreescribía el `Authorization` real del cliente cuando no se enviaba `X-Backend-Token`.

**API key activa:**
```
6bab1d02-6a3b-4eb1-ab1d-026a3bfeb1d1
```
*(Visible en: Applications → app suscrita → Subscriptions)*

---

## 3. WSO2 APIM

### 3.1 Credenciales de acceso

| Consola | URL | Usuario | Contraseña |
|---|---|---|---|
| Publisher | `https://apim-wso2.local:30443/publisher` | `admin` | (desde Vault) |
| Dev Portal | `https://apim-wso2.local:30443/devportal` | `admin` | (desde Vault) |
| Gateway | `https://api-wso2.local:30443` | — | — |
| Carbon Console | `https://apim-wso2.local:30443/carbon` | `admin` | (desde Vault) |

### 3.2 Bug: Error 900900 – "Unclassified Authentication Failure"

Este fue el bug más complejo de la PoC. Requirió tres iteraciones hasta llegar a la causa raíz real.

**Síntoma**
Al consumir el API con `X-APIM-Authorization: Bearer <token>` se recibía:
```json
{"code":"900900","message":"Unclassified Authentication Failure"}
```

**Contexto del API configurado**
- API importado desde `http://10.50.129.101:5511/v3/api-docs`
- Application Level Security configurado como `X-APIM-Authorization` en el Runtime
- Aplicación `app-movil` suscrita y con estado `UNBLOCKED`
- Token generado correctamente con `client_credentials`

---

#### Iteración 1 — Diagnóstico inicial

Se verificaron los logs del gateway WSO2:
```
ERROR {JWTValidatorImpl} - Error while connecting to JWKS endpoint
java.net.UnknownHostException: apim-wso2.local: Name or service not known
```

**Causa:** El pod de WSO2 no podía resolver `apim-wso2.local` internamente. Al recibir un token JWT con `iss=https://apim-wso2.local:30443/oauth2/token`, el componente `JWTUtil.retrieveJWKSConfiguration` construye la URL del JWKS como `https://apim-wso2.local:30443/oauth2/jwks` y hace un HTTP GET usando Apache HttpClient. Como el hostname no existe dentro del cluster, falla con `UnknownHostException` → error 900900.

**Fix intentado:** Agregar `[[apim.jwt.issuer]]` en `deployment.toml` con `jwks_uri = "https://localhost:9443/oauth2/jwks"`.

**Resultado:** No solucionó el problema. `JWTUtil` ignora esta configuración para derivar la URL del JWKS; la construye directamente desde el claim `iss` del token.

---

#### Iteración 2 – Resolución DNS con hostAliases

**Fix aplicado:** Agregar `hostAliases` en el Deployment para inyectar la entrada DNS en `/etc/hosts` del pod:

```yaml
# 20-deployment.yaml
spec:
  template:
    spec:
      hostAliases:
      - ip: "172.16.14.185"   # IP del nodo
        hostnames:
        - "apim-wso2.local"
        - "api-wso2.local"
```

**Resultado:** El DNS se resolvió, pero apareció un nuevo error:
```
SSLHandshakeException: Failed to parse server certificates
```

El hostname `apim-wso2.local` resolvía a la IP del nodo (172.16.14.185), puerto 30443, que es el NGINX Ingress. El certificado TLS que NGINX presentaba tenía Subject e Issuer vacíos (cert-manager `selfsigned-issuer`), lo que Apache HttpClient de Java no podía parsear.

---

#### Iteración 3 – Bypass de NGINX con ClusterIP service (FIX DEFINITIVO)

**Análisis:** El problema raíz era que la URL del JWKS (`https://apim-wso2.local:30443/oauth2/jwks`) iba a través de NGINX, que presentaba un certificado roto. La solución: hacer que esa URL apunte directamente al pod de WSO2 en su puerto nativo 9443, donde el certificado es correcto (`CN=apim-wso2.local`, emitido por el propio WSO2).

**Fix aplicado — dos cambios:**

**1. Nuevo puerto en el Service de WSO2** ([30-service.yaml](../manual/manifests/wso2/30-service.yaml)):
```yaml
- name: https-proxy
  port: 30443
  targetPort: 9443
```
El Service ClusterIP `wso2apim` (IP: `10.43.106.116`) ahora expone el puerto 30443 y lo dirige al pod en 9443.

**2. hostAliases actualizado** ([20-deployment.yaml](../manual/manifests/wso2/20-deployment.yaml)):
```yaml
hostAliases:
- ip: "10.43.106.116"    # ClusterIP del service wso2apim
  hostnames:
  - "apim-wso2.local"
- ip: "172.16.14.185"    # IP del nodo (para acceso externo vía NGINX)
  hostnames:
  - "api-wso2.local"
```

**Flujo resultante:**
```
WSO2 pod → JWKS URL: https://apim-wso2.local:30443/oauth2/jwks
         → apim-wso2.local resuelve a 10.43.106.116 (ClusterIP)
         → Service redirige 30443 → 9443 (pod WSO2)
         → WSO2 responde con su propio cert (CN=apim-wso2.local)
         → Cert es de confianza (está en el truststore)
         → JWKS obtenido → token validado ✅
```

**Resultado:** Error 900900 eliminado. El token se valida correctamente.

---

### 3.3 Configuración del API ONP Thaqhiri

**Estado:** Operativo ✅

| Parámetro | Valor |
|---|---|
| Nombre | ONPThaqhiriAPI |
| Context path | `/onpthaqhiriapi/1.0.0` |
| Backend | `http://10.50.129.101:5511` |
| Estado | Published / Deployed |
| Plan de seguridad | Application Level Security → `X-APIM-Authorization` |
| Aplicación suscrita | `app-movil` (UNBLOCKED) |

**Credenciales OAuth2 de `app-movil`:**

| Campo | Valor |
|---|---|
| Client ID | `YTuTDJC9KbBNEF4TabfrRyqCatsa` |
| Client Secret | `EMM5QaiQ6YNmQq6wAdX2TOPFYlMa` |

**Generar token APIM (válido 1 hora):**
```bash
curl -sk -X POST "https://apim-wso2.local:30443/oauth2/token" \
  -H "Content-Type: application/x-www-form-urlencoded" \
  -d "grant_type=client_credentials&client_id=YTuTDJC9KbBNEF4TabfrRyqCatsa&client_secret=EMM5QaiQ6YNmQq6wAdX2TOPFYlMa"
```

---

## 4. Referencia rápida de consumo

### 4.1 WSO2 APIM

```bash
# 1. Generar token APIM (desde cualquier máquina con acceso a apim-wso2.local:30443)
TOKEN=$(curl -sk -X POST "https://apim-wso2.local:30443/oauth2/token" \
  -d "grant_type=client_credentials&client_id=YTuTDJC9KbBNEF4TabfrRyqCatsa&client_secret=EMM5QaiQ6YNmQq6wAdX2TOPFYlMa" \
  | python3 -c "import sys,json; print(json.load(sys.stdin)['access_token'])")

# 2. Consumir el API
curl -sk \
  -H "X-APIM-Authorization: Bearer $TOKEN" \
  -H "Authorization: Bearer <token-del-backend-SAA>" \
  "https://api-wso2.local:30443/onpthaqhiriapi/1.0.0/api/horarios"
```

**Headers:**
| Header | Valor | Propósito |
|---|---|---|
| `X-APIM-Authorization` | `Bearer <jwt-apim>` | Autenticación en WSO2 (expira en 1h) |
| `Authorization` | `Bearer <token-saa>` | Token del backend SAA (pasa directo) |

### 4.2 Gravitee APIM

```bash
# No requiere generar token previo — la API key es estática
curl -sk \
  -H "X-APIM-Authorization: 6bab1d02-6a3b-4eb1-ab1d-026a3bfeb1d1" \
  -H "Authorization: Bearer <token-del-backend-SAA>" \
  "https://api-gravitee.local:30443/onpthaqhiriapi/api/horarios"
```

**Headers:**
| Header | Valor | Propósito |
|---|---|---|
| `X-APIM-Authorization` | `<api-key>` (sin Bearer) | Autenticación en Gravitee (estática, no expira) |
| `Authorization` | `Bearer <token-saa>` | Token del backend SAA (pasa directo) |

### 4.3 Diferencias clave entre productos

| Característica | WSO2 | Gravitee (plan actual) |
|---|---|---|
| Tipo de credencial APIM | JWT OAuth2 (expira) | API Key estática |
| Cómo obtener acceso | Generar token con client_credentials | Usar la key directamente |
| Header APIM | `X-APIM-Authorization: Bearer <jwt>` | `X-APIM-Authorization: <key>` |
| Rotación de credencial | Cada hora (o configurar duración) | Manual o por fecha de expiración |
| Configuración duración token | `deployment.toml` → `[oauth]` o por app en UI | Por suscripción o key individual |

### 4.4 Hosts necesarios en cada máquina cliente

Agregar en `/etc/hosts` (Linux/Mac) o `C:\Windows\System32\drivers\etc\hosts` (Windows):

```
172.16.14.185   apim-wso2.local
172.16.14.185   api-wso2.local
172.16.14.185   apim-gravitee.local
172.16.14.185   api-gravitee.local
172.16.14.185   portal-gravitee.local
```

---

## 5. Pendientes y mejoras identificadas

### 5.1 Funcionales

| # | Ítem | Producto | Prioridad |
|---|---|---|---|
| F-01 | Migrar Gravitee de API Key a plan OAuth2/JWT para credenciales equivalentes a WSO2 | Gravitee | Media |
| F-02 | Configurar duración del token WSO2 a nivel global (actualmente 1h por defecto) | WSO2 | Baja |
| F-03 | Publicar APIs en el Developer Portal de Gravitee para autoservicio | Gravitee | Media |
| F-04 | Configurar rate limiting en ambos productos para los casos B2B/B2C | Ambos | Alta |
| F-05 | Completar casos de prueba C1-C11 definidos en `poc-blueprint-apim-k3s_actualizado.md` | Ambos | Alta |

### 5.2 Operativas / Infraestructura

| # | Ítem | Producto | Prioridad |
|---|---|---|---|
| O-01 | Elasticsearch: documentar que requiere mínimo 2 réplicas master en este entorno | Gravitee | Alta |
| O-02 | Agregar cert de PoC al sistema operativo del nodo y máquinas cliente para eliminar `-k` en curl | Infra | Media |
| O-03 | Documentar el proceso de rotación de API keys en Gravitee | Gravitee | Baja |
| O-04 | Kong Enterprise: pendiente de instalación y configuración | Kong | Alta |
| O-05 | Configurar Prometheus/Grafana para métricas de ambos APIMss | Infra | Media |

### 5.3 Para el documento técnico definitivo

- [ ] Completar matriz de comparación C1-C11 con resultados reales de cada producto
- [ ] Agregar capturas de pantalla de Publisher, DevPortal y Gateway de cada producto
- [ ] Documentar configuración B2B/B2C con tokens separados por audiencia
- [ ] Incluir resultados de pruebas de carga k6 (S0-S3)
- [ ] Agregar sección de scoring con los criterios de `poc-blueprint-apim-k3s_actualizado.md`

---

## Anexo A – Archivos modificados durante la PoC

| Archivo | Cambio | Motivo |
|---|---|---|
| `manual/manifests/wso2/10-configmap.yaml` | Agregado `[[apim.jwt.issuer]]` con `jwks_uri` | Intento de fix 900900 (parcial) |
| `manual/manifests/wso2/20-deployment.yaml` | `hostAliases` → `apim-wso2.local: 10.43.106.116` | Fix 900900 — DNS interno |
| `manual/manifests/wso2/30-service.yaml` | Puerto `30443 → 9443` agregado | Fix 900900 — bypass NGINX |
| `manual/manifests/wso2/40-ingress.yaml` | Eliminado `cert-manager.io/cluster-issuer` | Fix TLS cert vacío |
| `manual/manifests/wso2/41-ingress-gateway.yaml` | Eliminado `cert-manager.io/cluster-issuer` | Fix TLS cert vacío |

## Anexo B – Comandos de diagnóstico útiles

```bash
# Estado general de los namespaces APIM
kubectl get pods -n apim-wso2
kubectl get pods -n apim-gravitee

# Logs WSO2 (últimos errores de autenticación)
kubectl logs -n apim-wso2 deployment/wso2apim -c wso2apim --since=5m \
  | grep -E "900900|900901|900902|JWTValid|ERROR"

# Logs Gravitee API
kubectl logs -n apim-gravitee deployment/gravitee-apim3-api --since=5m | grep -i error

# Logs Elasticsearch
kubectl logs -n apim-gravitee graviteeio-apim-elasticsearch-master-0 --since=5m | tail -20

# Verificar cert TLS en uso
echo | openssl s_client -connect api-wso2.local:30443 -servername api-wso2.local 2>/dev/null \
  | openssl x509 -text -noout | grep -E "Subject:|Issuer:|Not After"

# Test JWKS desde dentro del pod WSO2
kubectl exec -n apim-wso2 deployment/wso2apim -- \
  curl -sk https://apim-wso2.local:30443/oauth2/jwks | python3 -m json.tool
```
