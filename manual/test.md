# PoC APIM On-Prem – Baseline de Seguridad y APIs de Ejemplo (Manual)

## Contexto
Esta PoC evalúa soluciones APIM on‑premise (WSO2, Gravitee, Kong) desplegadas en K3s, con exposición a Internet bajo un modelo **B2B / B2C**.
El objetivo es validar **seguridad, gobierno y operabilidad**, no solo conectividad.

---

## 1. Arquitectura de referencia

### Flujo de la request
Cliente / Partner / App
|
v
[WAAP]
|
v
[NGINX Ingress]
|
v
[API Management]
|
v
[Backends]

### Responsabilidades por capa
- **WAAP:** protección perimetral y anti‑abuso
- **Ingress:** ruteo técnico dentro de K3s
- **APIM:** identidad, contrato, gobierno y observabilidad
- **Backends:** lógica de negocio

---

## 2. Baseline de seguridad para la PoC

### 2.1 Supuestos base
- APIM on‑premise en K3s
- Single tenant
- Exposición a Internet
- Consumidores externos (partners y apps)
- WAAP como punto de entrada

### 2.2 Capa 1 – Perímetro (WAAP)
Aplica a **todas** las APIs.
- TLS 1.2+ (ideal 1.3)
- Protección OWASP Top 10
- Protección básica contra bots
- Rate limiting global anti‑abuso
- Inspección de tráfico HTTPS
- Logging de eventos de seguridad

**Criterio de éxito**
Requests maliciosas se bloquean antes de llegar al APIM.

### 2.3 Capa 2 – Canal seguro
- HTTPS obligatorio extremo a extremo
- Certificados válidos (internos o públicos)
- Preservación de headers: `X-Forwarded-For`, `X-Request-ID`

### 2.4 Capa 3 – Identidad y autenticación (APIM)
**B2B – Partners externos**
- OAuth2 Client Credentials
- Un cliente OAuth por empresa
- Scopes por API
- (Opcional PoC) mTLS

**B2C – Aplicaciones propias**
- OAuth2 Authorization Code
- Tokens por usuario
- Scopes funcionales

**Criterio de éxito**
Toda request es trazable a un consumidor identificado.

### 2.5 Capa 4 – Control de consumo
- Rate limit por cliente
- Quota mensual
- Diferenciación de planes: Básico / Premium

### 2.6 Capa 5 – Gobierno de APIs
- Agrupación por dominio funcional
- Versionado explícito (/v1, /v2)
- Políticas reutilizables
- Estrategia de deprecación documentada

### 2.7 Capa 6 – Observabilidad y auditoría
- Métricas por API
- Métricas por consumidor
- Logs con correlation ID
- Dashboard básico de uso

Pregunta clave: ¿Quién consumió qué API, cuándo y cuánto?

---

## 3. APIs de ejemplo para la PoC

### 3.1 API B2B – Partner Orders API
**Path:** `/partner/orders`

**Características**
- OAuth2 Client Credentials
- Rate limit por partner
- Quota mensual
- Validación de esquema JSON
- Acceso restringido por scope

**Casos de prueba**
- Token inválido
- Partner sin permisos
- Exceso de rate limit
- Aislamiento de datos entre partners

### 3.2 API B2C – Customer Profile API
**Path:** `/customer/profile`

**Características**
- OAuth2 Authorization Code
- Token por usuario
- Scopes: `profile.read`, `profile.update`
- Rate limit por usuario

**Casos de prueba**
- Token expirado
- Falta de scope
- Uso de refresh token

### 3.3 API Legacy – Legacy Billing API
**Path:** `/legacy/billing`

**Características**
- Backend legacy simulado
- Transformación request/response
- Traducción de autenticación (API Key → OAuth)
- Throttling agresivo

**Objetivo**
Demostrar el valor del APIM como capa de modernización.

### 3.4 API interna – Health API
**Path:** `/health`

**Características**
- Acceso solo desde red interna
- Sin autenticación externa
- Uso exclusivo de operaciones

---

## 4. Ejecución de la PoC
1. Implementar las 4 APIs en cada APIM
2. Aplicar el mismo baseline de seguridad
3. Documentar: tiempo de configuración, complejidad operativa, facilidad de cambios
4. Simular fallos y ataques
5. Medir: latencia, gobierno, observabilidad

---

## 5. Resultado esperado
- ¿Qué APIM gestiona mejor escenarios B2B/B2C?
- ¿Cuál es más simple de operar on‑prem?
- ¿Cuál ofrece mejor gobierno y trazabilidad?
- ¿Dónde es más costoso el cambio de políticas?
