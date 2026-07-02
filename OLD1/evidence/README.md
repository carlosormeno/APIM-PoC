# Kit de evidencias

Estructura recomendada:

```
+evidence/
+  YYYY-MM-DD/
+    wso2/
+      round-1/
+        screenshots/
+        k6/
+        grafana/
+        logs/
+        infra/
+      round-2/
+      round-3/
+    gravitee/
+    kong/
+```

## Qué guardar en cada carpeta
- `screenshots/`: UI Publisher/Portal, configuración de policies, RBAC, etc.
- `k6/`: `--summary-export` en JSON y, si aplica, logs del test.
- `grafana/`: export JSON de dashboards + capturas.
- `logs/`: fragmentos relevantes de Loki o logs del APIM.
- `infra/`: baseline de versiones (k3s/helm/charts/APIM) + IP/NodePort.

> Regla: toda evidencia debe ser reproducible y estar asociada a producto y ronda.

## Reglas de documentación (obligatorias)
- Documentar **todo** cambio/ajuste, incluso si es menor.
- Cada cambio debe registrarse con **fecha (YYYY-MM-DD)**, motivo, impacto y responsable.
- Ningún cambio se considera válido si no queda en el kit de evidencias.

### Registro de cambios
Crea un archivo `changes.log` dentro de cada producto y ronda, por ejemplo:

```
evidence/2026-01-29/wso2/round-1/changes.log
```

Formato sugerido:
```
YYYY-MM-DD HH:MM  cambio breve  motivo  impacto  responsable
```
