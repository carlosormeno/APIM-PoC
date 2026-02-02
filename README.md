# PoC APIM – Evaluación Comparativa (Gestión)

## Propósito
Esta PoC busca **comparar de forma imparcial** tres plataformas de API Management (APIM) para decidir cuál se adapta mejor a nuestras necesidades. La evaluación considera no solo aspectos técnicos, sino también **operación, seguridad, gobernanza y esfuerzo de adopción**.

## Alcance
Se evaluarán tres soluciones APIM:
- **Gravitee APIM**
- **WSO2 API Manager**
- **Kong Enterprise** (se evaluará en la etapa final)

La PoC se realizará en entorno **on‑premise** con un set de pruebas y evidencias homogéneas para asegurar comparabilidad.

## Qué vamos a comparar
- **Seguridad** (autenticación, autorización, controles de acceso, políticas)
- **Performance** (latencia, throughput, errores)
- **Operación** (instalación, mantenimiento, actualizaciones, observabilidad)
- **Gobierno** (roles, auditoría, trazabilidad, versionado)
- **Experiencia de desarrolladores** (portal, onboarding, claridad de uso)

## Enfoque de evaluación
- Se define un **baseline común** para los 3 productos.
- Se ejecutan **casos B2B y B2C reales** (no “hello world”).
- Se recogen evidencias con fecha y hora.
- Se documenta **cada ajuste o cambio** realizado.

## Entregables
Al finalizar la PoC se generará un **informe comparativo** con:
- Matriz de scoring
- Evidencias (capturas, logs, métricas, reportes de carga)
- Riesgos y mitigaciones
- Recomendación final

## Principio de imparcialidad
El objetivo es ser **lo más objetivos e imparciales posible**. Todas las plataformas se prueban con el **mismo criterio** y en el mismo entorno, evitando ventajas o ajustes ad‑hoc no documentados.

---

Para detalles técnicos, consultar:
- `poc-blueprint-apim-k3s_actualizado.md`
- `runbook-0-base-apim-poc.md`
- `runbook-1-gravitee-apim.md`
- `runbook-2-wso2-apim.md`
- `runbook-3-kong-enterprise.md`
