# Checklist Zero Trust – PoC APIM B2B / B2C (Manual)

## 0. Principios base
- No se confía por red, IP o ubicación
- Toda request debe autenticarse
- Acceso mínimo necesario (least privilege)
- Asumir compromiso
- Todo es auditable

## 1. Perímetro – WAAP
- TLS 1.2+ (ideal 1.3)
- OWASP Top 10 habilitado
- Protección básica contra bots
- Rate limiting global anti‑abuso
- Inspección HTTPS activa
- Bloqueo de payloads inválidos
- Logging de eventos de seguridad
- WAAP no hace autenticación de negocio

Resultado esperado: requests maliciosas no llegan al APIM.

## 2. Canal seguro
- HTTPS obligatorio en todos los saltos
- Certificados válidos y rotados
- Preservación de `X-Forwarded-For`
- Preservación de `X-Request-ID`
- No hay tráfico plano interno

## 3. Ingress (NGINX – K3s)
- Solo acepta tráfico desde el WAAP
- mTLS WAAP → Ingress (si es posible)
- Sanitización de headers
- No hace auth ni lógica de negocio
- No confía implícitamente en la red interna

Regla clave: pasar por el ingress ≠ request confiable.

## 4. Identidad externa (Clientes / Partners)
**B2B**
- OAuth2 Client Credentials obligatorio
- Un cliente OAuth por empresa
- Scopes por API / operación
- (Opcional) mTLS por partner
- Tokens con audience estricta

**B2C**
- OAuth2 Authorization Code
- OIDC habilitado
- Scopes funcionales
- Refresh tokens controlados

## 5. APIM – Corazón Zero Trust
- Autenticación obligatoria en todas las APIs
- Deny‑by‑default
- Validación de token en cada request
- Validación de scopes
- Rate limit por consumidor
- Quotas por plan
- Versionado explícito de APIs
- Políticas reutilizables
- No se confía en tráfico “interno”

## 6. Tokens y credenciales
- Tokens de corta duración (5–10 min)
- Rotación de secretos
- No tokens hardcodeados
- Revocación soportada
- Credenciales por consumidor, no compartidas

## 7. Validación de requests
- Validación de esquema JSON
- Métodos HTTP permitidos explícitos
- Tamaño máximo de payload
- Headers esperados definidos
- Bloqueo de input inesperado

## 8. Backend Services (Zero Trust real)
- mTLS APIM → Backend
- Backend valida JWT
- Validación de issuer y audience
- Autorización por claims
- Network Policies en K3s
- Backend no confía ciegamente en el APIM

Regla clave: el backend también desconfía.

## 9. Control de impacto (Blast Radius)
- Rate limits conservadores
- Quotas bajas por defecto
- Scopes granulares
- Circuit breakers configurados
- APIs críticas separadas

## 10. Observabilidad y auditoría
- Correlation ID end‑to‑end
- Logs centralizados
- Métricas por API
- Métricas por consumidor
- Alertas por comportamiento anómalo
- Auditoría de accesos

## 11. Pruebas obligatorias de la PoC
- Request sin token → bloqueada
- Token inválido → bloqueada
- Scope incorrecto → bloqueada
- Exceso de rate limit → bloqueada
- Partner A no accede a data de Partner B
- Token expirado → bloqueada

## 12. Criterio de éxito Zero Trust
- Ninguna request pasa sin identidad
- Cada acceso es trazable
- Impacto de credencial comprometida es limitado
- Seguridad y negocio desacoplados
- Modelo operable on‑prem

Frase para comité / seguridad:
"No confiamos ni en la red, ni en el cluster, ni en nosotros mismos. Cada request se verifica, autoriza y audita."
