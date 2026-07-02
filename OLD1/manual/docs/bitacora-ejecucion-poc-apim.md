# Bitacora de ejecucion - PoC APIM

## 1) Objetivo de la PoC
Preparar una plataforma base en k3s para evaluar APIMs en condiciones comparables, y luego ejecutar la evaluacion de:
- WSO2 APIM
- Gravitee APIM
- Kong Enterprise (si aplica licencia)

## 2) Que se busca validar
- Capacidad funcional B2B/B2C (planes, autenticacion, autorizacion, cuotas, rate limit).
- Facilidad operativa (instalacion, configuracion, troubleshooting, observabilidad).
- Integracion con componentes base:
  - Ingress NGINX
  - TLS con cert-manager
  - Vault para secretos
  - Observabilidad (Prometheus, Grafana, Loki, OTel)
- Desempeno y estabilidad con pruebas k6.

## 3) Herramientas y componentes bajo evaluacion
### APIMs
- WSO2 APIM
- Gravitee APIM
- Kong Enterprise

### Plataforma base
- k3s
- ingress-nginx
- cert-manager
- Vault (HashiCorp)
- Headlamp (operacion del cluster)
- Stack de observabilidad

## 4) Criterio de ejecucion y evidencia
- Ejecutar primero `runbook-0`.
- Levantar un APIM a la vez para no saturar la maquina.
- Registrar cambios, comandos y resultados en:
  - `evidence/<fecha>/base-baseline.txt`
  - esta bitacora
- No guardar secretos sensibles en el repositorio.

## 5) Bitacora de avance (2026-02-18)
### Contexto inicial
- Cluster k3s ya existente con componentes previos.
- Se confirmo acceso con `KUBECONFIG=$HOME/.kube/config`.

### Runbook 0 - Paso 1 (baseline)
- Baseline de versiones y estado inicial registrado en:
  - `evidence/2026-02-18/base-baseline.txt`
- Nota tecnica: `kubectl version --short` no aplica en esta version; se registro `kubectl version` completo.

### Runbook 0 - Paso 2 (Ingress NGINX)
- Validado como completo.
- `ingress-nginx-controller` en Running.
- Servicio NodePort activo con HTTPS.

### Runbook 0 - Paso 3 (/etc/hosts)
- Validado como completo.
- Dominios locales de APIM y observabilidad presentes y apuntando a IP del nodo.

### Runbook 0 - Paso 4 (cert-manager + issuer)
- Validado como completo.
- `ClusterIssuer selfsigned-issuer` en estado Ready.

### Runbook 0 - Paso 5 (Vault)
- Se decidio usar Vault local en el cluster para esta ejecucion.
- Vault instalado con Helm en namespace `vault`.
- Vault Agent Injector desplegado.
- Vault inicializado y desellado (umbral 3 de 5).
- Auth de Kubernetes configurada.
- Policies y roles creados:
  - `apim-wso2`
  - `apim-gravitee`
  - `apim-kong`
- Prueba de inyeccion OK en `apim-gravitee` (pod smoke test).

### Componente adicional solicitado (Headlamp)
- Headlamp instalado en namespace `headlamp`.
- Acceso por NodePort habilitado.

### Runbook 0 - Paso 6 (Observabilidad)
- Despliegue completado y validado.
- Componentes en Running:
  - prometheus-operator
  - prometheus
  - grafana
  - loki
  - otel-collector
  - alertmanager-receiver
- Se aplicaron correcciones de manifests para compatibilidad:
  - `manual/manifests/observability/loki-configmap.yaml`
  - `manual/manifests/observability/otel-configmap.yaml`
  - `manual/manifests/observability/prometheus-operator/prometheus.yaml`
  - `manual/manifests/observability/prometheus-operator/prometheus-rbac.yaml` (nuevo)

## 6) Riesgos / notas operativas
- Vault requiere unseal manual tras reinicio.
- Archivo temporal de inicializacion de Vault existe fuera del repo:
  - `/tmp/vault-bootstrap/vault-init-2026-02-18-141448.json`
- Accion requerida: mover llaves a almacenamiento seguro y eliminar archivo temporal local.

## 7) Pendientes inmediatos
- Runbook 0 Paso 7: validar acceso Grafana por Ingress HTTPS.
- Runbook 0 Paso 8: desplegar backends `poc-backends`.
- Runbook 0 Paso 9: preparar `poc-loadgen` y prueba de conectividad.
- Runbook 0 Paso 10: registrar headroom (CPU/RAM) antes de APIM.
- Continuar con runbook de APIM seleccionado (WSO2 o Gravitee).

## 8) Regla de actualizacion de esta bitacora
Por cada paso ejecutado:
1. Registrar que se quiso hacer.
2. Registrar que se ejecuto.
3. Registrar resultado (OK / parcial / fallo) con causa.
4. Registrar evidencia (ruta de archivo, captura o log).


### Runbook 0 - Paso 7 (Grafana por Ingress HTTPS)
- Validado como completo.
- Ingress `monitoring/grafana` activo con TLS (`grafana-tls`).
- Acceso funcional probado por HTTPS via NodePort de ingress-nginx:
  - `https://grafana.local:30443` (con resolve al node IP)
- Ajuste aplicado para funcionamiento correcto cross-namespace en ingress-nginx:
  - se agrego permiso RBAC de `endpointslices.discovery.k8s.io` en `manual/manifests/ingress/20-clusterrole.yaml`.

### Runbook 0 - Paso 8 (Backends PoC)
- Ejecutado y validado.
- Namespace `poc-backends` desplegado con:
  - `svc-fast`
  - `svc-slow`
  - `svc-error`
- Smoke test interno exitoso:
  - `svc-fast` responde HTTP 200
  - `svc-slow` responde HTTP 200 con delay esperado
  - `svc-error` responde HTTP 500 (escenario de error controlado)

### Runbook 0 - Paso 9 (LoadGen con k6)
- Ejecutado y validado.
- Namespace `poc-loadgen` confirmado.
- Se ejecuto smoke test real con `grafana/k6` contra backend interno `svc-fast.poc-backends.svc.cluster.local`.
- Resultado:
  - `status is 200` OK
  - `checks_succeeded=100%`
  - `http_req_failed=0%`
- Nota tecnica:
  - La imagen `grafana/k6` no permite `apk add` por permisos (non-root), por lo que la validacion se hizo con script k6 directo.

### Runbook 0 - Paso 10 (Headroom y regla operativa)
- Ejecutado y validado.
- Medicion actual:
  - `kubectl top nodes`: CPU ~4%, memoria ~32% en nodo.
  - `free -h`: memoria disponible suficiente para continuar.
- Regla operativa confirmada:
  - No hay pods activos en namespaces de APIM (`apim-gravitee`, `apim-wso2`, `apim-kong`).
  - Se mantiene criterio de levantar un APIM a la vez.

## 9) Avance WSO2 (runbook-2)
### Paso 1 - Instalacion manual
- Aplicados manifests de `manual/manifests/wso2/`.
- Vault completado con secretos requeridos para WSO2:
  - `kv/apim/wso2/db`
  - `kv/apim/wso2/postgres`
  - `kv/apim/wso2/keystore`
  - `kv/apim/wso2/truststore`
- Ajustes tecnicos realizados:
  - `manual/manifests/wso2/20-deployment.yaml`: `vault.hashicorp.com/agent-init-first: "true"` para que Vault inyecte secretos antes del initContainer `render-config`.
  - `manual/manifests/wso2/40-ingress.yaml`: `nginx.ingress.kubernetes.io/backend-protocol: "HTTPS"`.
  - `manual/manifests/wso2/41-ingress-gateway.yaml`: `nginx.ingress.kubernetes.io/backend-protocol: "HTTPS"`.
- Estado final del paso:
  - `wso2-postgres` Running
  - `wso2apim` Running
  - Ingress management y gateway operativos por HTTPS (NodePort 30443).

### WSO2 - ajuste de login/redirect (localhost)
- Se detecto redireccion a `localhost:9443` en flujo de autenticacion.
- Se estabilizo deployment de WSO2 (pod `wso2apim` Running).
- Se reforzo Ingress de management para reescritura de redirects hacia `https://apim-wso2.local:30443`.
- Recomendacion operativa al usuario: iniciar siempre desde URL base del Publisher y limpiar sesion/cookies antiguas.

### WSO2 - publicacion de API desde Swagger remoto y prueba con doble token
- Se publico API `ONPThaqhiriAPI` version `1.0.0` a partir de OpenAPI remoto:
  - `http://10.50.129.101:5511/v3/api-docs`
- Configuracion funcional usada en Publisher:
  - Contexto: `/onpthaqhiriapi`
  - Endpoint backend: `http://10.50.129.101:5511`
  - Security: OAuth2 (APIM)
  - Plan: `Unlimited`
- Despliegue:
  - Revision desplegada en gateway `Default`
  - API en estado `PUBLISHED`
- Caso de backend con token propio (ademas del token APIM):
  - En Runtime se cambio `Authorization Header` a `X-APIM-Authorization`
  - Se uso invocacion con 2 headers:
    - `X-APIM-Authorization: Bearer <token_apim>`
    - `Authorization: Bearer <token_backend>`
  - Resultado validado: `200 OK` via APIM para `GET /api/horarios`
- Nota de troubleshooting:
  - Error `900902 Missing Credentials`: APIM no recibia token en header esperado.
  - Error `900901 Invalid Credentials`: token APIM invalido/expirado.
  - Error backend `Token invalido segun SAA`: token backend invalido/expirado o no enviado correctamente.
- Operacion de token APIM:
  - Se documento regeneracion de access token por `curl` con `grant_type=client_credentials`
  - Endpoint operativo en PoC: `https://apim-wso2.local:30443/oauth2/token`

## 10) Avance Gravitee (runbook-1) - 2026-02-20
### Cambio de enfoque operativo
- Se pauso WSO2 para evitar competicion de recursos:
  - `apim-wso2/wso2apim` escalado a `0`
  - `apim-wso2/wso2-postgres` escalado a `0`
- Se continuo con Gravitee como APIM activo de la sesion.

### Despliegue inicial
- Aplicados manifests de `manual/manifests/gravitee/`.
- Hallazgos y correcciones:
  - Imagen de portal incorrecta en deployment:
    - de `graviteeio/apim-portal:4.10.3`
    - a `graviteeio/apim-portal-ui:4.10.3`
  - Faltaba secreto en Vault para Mongo:
    - `kv/apim/gravitee/mongo` con clave `password`
  - Servicios de UI apuntaban a puertos no reales del contenedor:
    - `gravitee-console` y `gravitee-portal` escuchan en `8080`
    - se corrigio `targetPort` en servicios y `containerPort` en deployments.

### Estado final validado
- Pods en `apim-gravitee`:
  - `gravitee-mongo` Running
  - `gravitee-management-api` Running
  - `gravitee-gateway` Running
  - `gravitee-console` Running
  - `gravitee-portal` Running
- Pruebas por ingress (NodePort TLS `30443`):
  - `Host: apim-gravitee.local` -> `HTTP/2 200`
  - `Host: portal-gravitee.local` -> `HTTP/2 200`
  - `Host: api-gravitee.local` -> `HTTP/2 404` en `/` (esperado en root del gateway)

## 11) Gravitee - troubleshooting extendido (2026-02-20)
### Separacion de puertos por APIM
- Se mantuvo WSO2 en `30443`.
- Para Gravitee se habilito NodePort HTTPS alterno:
  - `31443` en `ingress-nginx-controller` (`port 444 -> targetPort https`).
- URLs operativas definidas para Gravitee:
  - `https://apim-gravitee.local:31443`
  - `https://portal-gravitee.local:31443`
  - `https://api-gravitee.local:31443`

### Hallazgos tecnicos y correcciones aplicadas
- `gravitee-management-api` no iniciaba correctamente en varios ciclos por configuracion faltante/inconsistente:
  - Se agrego `jwt.secret` en config de management.
  - Se agrego `http.secureHeaders.referrerPolicy.policy` para evitar error `Invalid referrer policy provided: 'null'`.
  - Se corrigio el montaje de configuracion para usar `subPath` de `gravitee.yml` (evitar sobreescritura total de carpeta config).
- Se ajusto config de context path de management:
  - `http.api.management.entrypoint` + `proxyPath`.
- `gravitee-gateway` no iniciaba por:
  - `No repository type defined in configuration for ratelimit`
  - Se agrego bloque `ratelimit` con Mongo en `gravitee.yml`.

### Validaciones por curl (estado)
- `GET /management/v2/ui/bootstrap` via ingress Gravitee:
  - responde `HTTP 200`.
- `GET /management/organizations/DEFAULT/console`:
  - responde `HTTP 200`.
- `Portal`:
  - responde `HTTP 200`.
- `Gateway root /`:
  - responde `HTTP 404` (esperado en raiz, sin API publicada aun).

### Riesgo/pendiente funcional actual
- El bootstrap de management sigue reportando:
  - `"baseURL": "https://apim-gravitee.local/management"` (sin `:31443`).
- Efecto:
  - En navegador puede haber error de CORS/NetworkError al intentar consumir por `443` cuando el acceso real de PoC es `31443`.
- Mitigacion operativa discutida:
  - redireccion local `443 -> 31443` en host Ubuntu para pruebas de UI.

## 12) Gravitee - realineacion con guia oficial y cierre (2026-02-23)
### Objetivo del ajuste
- Salir del despliegue manual inestable y alinear instalacion con chart oficial de Gravitee (`graviteeio/apim3`), manteniendo separacion de puertos de la PoC:
  - WSO2 -> `30443`
  - Gravitee -> `31443`

### Acciones ejecutadas
- Se mantuvo `ingress-nginx-controller` con dos NodePort HTTPS:
  - `443 -> 30443`
  - `444 -> 31443`
- Se elimino y recreo el namespace de Gravitee para instalacion limpia:
  - `kubectl delete ns apim-gravitee`
  - `kubectl create ns apim-gravitee`
- Se realizo instalacion por Helm del chart oficial:
  - `helm upgrade --install gravitee graviteeio/apim3 --version 4.10.3 ...`
- Se consolidaron ajustes en `APIM/gravitee/values.yaml` para el entorno PoC:
  - MongoDB standalone con parametros compatibles para k3s local.
  - Analytics/reporter de Elasticsearch deshabilitado para evitar dependencia no levantada en esta ejecucion.
  - Override explicito de host Mongo usado por APIM (`mongo.dbhost`) para evitar resolucion a `replicaset-headless`.
  - UI por Ingress en path `/console(/.*)?` con rewrite.
  - URLs publicas explicitas con `:31443`:
    - `ui.baseURL`
    - `installation.api.url`
    - `installation.standalone.console.url`
    - `installation.standalone.portal.url`

### Hallazgos de troubleshooting (resueltos)
- Error de imagen en init container de Mongo:
  - `docker.io/bitnami/os-shell:12-debian-12-r51` no encontrada.
- CrashLoop de Mongo por permisos:
  - `cp: cannot open .../conf.default/... Permission denied`.
- `api` y `gateway` no quedaban Ready por resolucion a host de Mongo no existente:
  - `UnknownHostException: graviteeio-apim-mongodb-replicaset-headless`.
- UI mostraba `Management API unreachable` por CORS:
  - `baseURL` sin `:31443` en `constants.json`/bootstrap.
- Conflicto Helm por override manual previo:
  - `kubectl set env` sobre `MGMT_API_URL` genero conflicto de apply; se removio el override manual y se dejo configuracion en Helm values.

### Estado final validado
- Pods en `apim-gravitee` en estado `Running`:
  - `gravitee-apim3-api`
  - `gravitee-apim3-gateway`
  - `gravitee-apim3-portal`
  - `gravitee-apim3-ui`
  - `graviteeio-apim-mongodb-replicaset`
- Validaciones HTTP:
  - `GET https://apim-gravitee.local:31443/management/v2/ui/bootstrap` -> `HTTP 200`
  - `baseURL` devuelve `https://apim-gravitee.local:31443/management`
  - `constants.json` de UI con `baseURL` en `:31443`
- Resultado funcional:
  - acceso a consola Gravitee operativo en `https://apim-gravitee.local:31443/console`

### Artefactos actualizados
- `APIM/gravitee/values.yaml`
- `manual/docs/runbook-1-gravitee-apim-manual.md`
- `manual/manifests/ingress/60-service.yaml`

## 13) Anexo tecnico detallado - Gravitee (paso a paso)
### 13.1 Sintoma inicial observado en UI
- En `https://apim-gravitee.local:31443/` y luego en `https://apim-gravitee.local:31443/console`:
  - banner: `Management API unreachable or error occurs, please check logs`.
- En consola de navegador:
  - errores CORS/Network hacia `https://apim-gravitee.local/management/...` (sin `:31443`).
  - en etapas previas tambien hubo errores de MIME (JS/CSS servidos como `text/html`) por conflicto de path de UI.

### 13.2 Hipotesis y validaciones de red/ruteo
- Hipotesis A: Ingress de management no responde.
  - Validacion: `curl -skD- https://apim-gravitee.local:31443/management/v2/ui/bootstrap`
  - Resultado: `HTTP 200` en varios ciclos, pero con `baseURL` inicialmente sin `:31443`.
- Hipotesis B: falla intermitente por readiness/startup.
  - Evidencia: logs de ingress-nginx con `502 connect() failed (111: Connection refused)` a upstream de management durante reinicios.
  - Mitigacion aplicada en etapa manual: probes de startup/readiness para management API.

### 13.3 Hipotesis de autenticacion
- Se verifico carga de provider `memory` en logs:
  - `Loading authentication provider of type memory at position 0`.
- Aun asi, login `admin/admin` fallaba:
  - `Authentication failed event for: admin`.
- Se intento resolver via DB:
  - consulta en Mongo: `db.users.find({username:\"admin\"})` -> `[]`.
- Conclusión:
  - la via manual quedo friccionada por mezcla de estados/config, y se decidio reinstalacion limpia oficial.

### 13.4 Realineacion con guia oficial (Helm)
- Se cambio de enfoque:
  - de manifests manuales en `manual/manifests/gravitee/*`
  - a chart oficial `graviteeio/apim3`.
- Se mantuvo requerimiento de PoC:
  - WSO2 por `30443`
  - Gravitee por `31443`.

### 13.5 Separacion formal de puertos en ingress-nginx
- Servicio `ingress-nginx-controller`:
  - `https` -> `nodePort 30443`
  - `https-alt` -> `nodePort 31443`
- Persistido en:
  - `manual/manifests/ingress/60-service.yaml`.

### 13.6 Limpieza total de Gravitee previa
- Comandos ejecutados:
  - `helm -n apim-gravitee uninstall gravitee || true`
  - `kubectl delete ns apim-gravitee --wait=true`
  - `kubectl create ns apim-gravitee`
- Motivo:
  - eliminar residuos de despliegue manual y conflictos de objetos Helm/server-side apply.

### 13.7 Incidencias durante instalacion Helm y solucion aplicada
- Incidencia 1: `helm repo update` con timeouts en repos no relacionados.
  - Mitigacion: usar cache local y fijar chart version disponible (`4.10.3`).
- Incidencia 2: validacion de imagen en subchart (`allowInsecureImages`).
  - Mitigacion: `global.security.allowInsecureImages: true`.
- Incidencia 3: Mongo `Init:ImagePullBackOff` por `bitnami/os-shell:12-debian-12-r51`.
  - Se ajusto estrategia del subchart Mongo para evitar dependencia inestable del init.
- Incidencia 4: Mongo `CrashLoopBackOff` con `Permission denied` en `conf.default`.
  - Se ajustaron parametros de seguridad del subchart Mongo para entorno k3s PoC.
- Incidencia 5: `api`/`gateway` no quedaban Ready por host inexistente:
  - `UnknownHostException: graviteeio-apim-mongodb-replicaset-headless`.
  - Fix: setear `mongo.dbhost: graviteeio-apim-mongodb-replicaset` y `mongo.rsEnabled: false`.
- Incidencia 6: gateway intentaba reporter de Elasticsearch sin endpoint.
  - Fix: `gateway.reporters.elasticsearch.enabled: false` y analytics sin ES para PoC.
- Incidencia 7: conflicto Helm con override manual:
  - `kubectl set env` en `MGMT_API_URL` genero conflicto de field manager (`kubectl-set`).
  - Fix: remover override manual y centralizar en Helm values.

### 13.8 Correccion final de URL publica (causa raiz de CORS)
- Causa raiz funcional:
  - la UI y/o bootstrap generaban URL sin `:31443`.
- Ajustes finales que cerraron el problema:
  - `ui.baseURL: https://apim-gravitee.local:31443/management`
  - `installation.api.url: https://apim-gravitee.local:31443/management`
  - `installation.standalone.console.url: https://apim-gravitee.local:31443/console`
  - `installation.standalone.portal.url: https://portal-gravitee.local:31443`
  - UI ingress en `/console(/.*)?` con rewrite.

### 13.9 Evidencias de cierre (comandos y salida esperada)
- Estado de pods:
  - `kubectl -n apim-gravitee get pods`
  - esperado: `api/gateway/portal/ui/mongodb` en `Running` y `READY 1/1`.
- Bootstrap management:
  - `curl -sk https://apim-gravitee.local:31443/management/v2/ui/bootstrap`
  - esperado: JSON con `"baseURL" : "https://apim-gravitee.local:31443/management"`.
- Constants de UI:
  - `kubectl -n apim-gravitee get configmap gravitee-apim3-ui -o jsonpath='{.data.constants\.json}'`
  - esperado: `"baseURL": "https://apim-gravitee.local:31443/management"`.
- Acceso web final:
  - `https://apim-gravitee.local:31443/console`
  - login operativo.

### 13.10 Estado final de funcionamiento
- Gravitee APIM operativo en `apim-gravitee` con instalacion Helm oficial.
- Separacion por puertos mantenida:
  - WSO2: `30443`
  - Gravitee: `31443`
- Problema original resuelto:
  - UI deja de fallar por CORS/Network hacia management al usar `baseURL` correcto con puerto.

### 13.11 Guia operativa rapida (Gravitee)
- URLs de uso en esta PoC:
  - Consola de administracion: `https://apim-gravitee.local:31443/console`
  - Portal de desarrolladores: `https://portal-gravitee.local:31443`
  - Gateway (base): `https://api-gravitee.local:31443`
- Credenciales iniciales validadas:
  - `admin / admin` (si no entra, revisar que no haya cambio manual de usuario en DB o valores Helm).
- Comprobaciones minimas antes de publicar APIs:
  - `kubectl -n apim-gravitee get pods` -> todo `Running`.
  - `curl -sk https://apim-gravitee.local:31443/management/v2/ui/bootstrap` -> `baseURL` con `:31443`.
  - `curl -skI https://api-gravitee.local:31443/` -> `404` esperado en raiz sin API publicada.
- Nota de herramienta:
  - en Gravitee, `404` en `/` del gateway no implica falla; la validacion real es invocar un path de API publicada.

### 13.12 Incidencia puntual de endpoint (slash extra)
- Sintoma:
  - Respuesta `HTTP 400` desde backend al invocar por Gravitee.
- Causa:
  - En `Endpoints`, el backend base estaba con un `/` extra despues del host/puerto.
  - Esto generaba un path invalido hacia el backend.
- Solucion:
  - Dejar el endpoint base exactamente como:
    - `http://10.50.129.101:5511`
  - Sin `/` final.
- Resultado:
  - La invocacion por Gravitee responde `HTTP 200` con datos.

### 13.13 Politica para token de backend (Transform Headers)
- Contexto:
  - Backend exige `Authorization: Bearer <token_backend>`.
  - Gravitee usa `API Key` para control de acceso.
- Configuracion aplicada en `Policies` (Request phase):
  - Policy: `Transform Headers`.
  - `Set/replace headers`:
    - `Authorization` = `Bearer {#request.headers['X-Backend-Token']}`
  - No usar `Remove headers` ni `Headers to keep` en este caso.
- Invocacion de prueba (cliente):
  - `X-Gravitee-Api-Key: <api_key>`
  - `X-Backend-Token: <token_backend>`
- Resultado:
  - Backend recibe el `Authorization` correcto y responde `HTTP 200`.

### 13.14 Plan API Key y gestion de claves
- Plan:
  - Crear un Plan de tipo `API Key` y publicarlo.
- Suscripcion:
  - En `Developer Portal`, crear una `Application` y suscribirla al plan `API Key`.
  - La suscripcion debe quedar en estado `Accepted`.
- Uso de la API Key:
  - En cada request enviar:
    - `X-Gravitee-Api-Key: <api_key>`
- Renombrar/rotar API Key:
  - Si la UI permite editar la `Name/Label` de la API Key, hacerlo desde la seccion `API Keys` de la aplicacion.
  - Si no existe opcion de renombre, crear una nueva API Key con el nombre correcto y **revocar** la anterior.

## 14) Anexo tecnico detallado - WSO2 (paso a paso)
### 14.1 Objetivo y alcance
- Dejar WSO2 APIM operativo en k3s con:
  - Management por `https://apim-wso2.local:30443`
  - Gateway por `https://api-wso2.local:30443`
- Integrado con:
  - PostgreSQL en `apim-wso2`
  - Vault Agent Injector para secretos
  - ingress-nginx con TLS en NodePort `30443`

### 14.2 Instalacion base ejecutada
- Namespace y manifests aplicados desde:
  - `manual/manifests/wso2/`
- Componentes levantados:
  - `wso2-postgres`
  - `wso2apim`
- Ingress aplicados:
  - `manual/manifests/wso2/40-ingress.yaml` (management)
  - `manual/manifests/wso2/41-ingress-gateway.yaml` (gateway)

### 14.3 Vault y render de configuracion (hallazgos y fix)
- Sintoma inicial:
  - riesgo de carrera entre inyeccion de secretos y init container `render-config`.
- Causa:
  - `render-config` podia arrancar antes de que Vault dejara archivos en `/vault/secrets`.
- Correccion aplicada:
  - annotation `vault.hashicorp.com/agent-init-first: "true"` en:
    - `manual/manifests/wso2/20-deployment.yaml`
- Resultado:
  - init containers completan en orden correcto.
  - `deployment.toml` y keystores se generan antes de iniciar `wso2apim`.

### 14.4 Trafico HTTPS ingress -> backend WSO2 (hallazgo y fix)
- Sintoma inicial:
  - fallos de acceso por ingress hacia servicio WSO2.
- Causa:
  - WSO2 expone management/gateway en HTTPS y el ingress no forzaba protocolo backend HTTPS.
- Correccion aplicada:
  - `nginx.ingress.kubernetes.io/backend-protocol: "HTTPS"` en:
    - `manual/manifests/wso2/40-ingress.yaml`
    - `manual/manifests/wso2/41-ingress-gateway.yaml`
- Resultado:
  - rutas de management y gateway responden por NodePort TLS `30443`.

### 14.5 Redirect a localhost en login (hallazgo y mitigacion)
- Sintoma observado:
  - durante autenticacion se veian redirects a `localhost:9443`.
- Impacto:
  - flujo de login no estable desde URL publica de PoC.
- Mitigacion aplicada:
  - ajuste de ingress de management para reescritura de redirects a:
    - `https://apim-wso2.local:30443`
  - recomendacion operativa:
    - iniciar siempre desde URL base del Publisher
    - limpiar cookies/sesion antiguas al cambiar configuracion

### 14.6 Ready `1/2` en pod `wso2apim` (analisis real en cluster)
- Sintoma:
  - pod `wso2apim-...` en `1/2 Running`.
- Diagnostico:
  - el contenedor `vault-agent` estaba `Ready`.
  - el contenedor `wso2apim` fallaba `startupProbe` en `https://<pod-ip>:9443/services/Version` con `connection refused`.
- Evidencia:
  - eventos con `Warning Unhealthy` de startup probe.
  - logs de WSO2 mostrando arranque completo (`WSO2 Carbon started ...`) despues del tiempo de warm-up.
- Conclusion:
  - no era fallo permanente de app, sino ventana de arranque despues de recreaciones de sandbox.
- Estado final:
  - pod en `2/2 Running`.

### 14.7 Falla de acceso web por DNS/NodePort (causa raiz)
- Sintoma:
  - `https://apim-wso2.local:30443/publisher/` no cargaba (`connection refused`).
- Causa raiz:
  - `apim-wso2.local` resolvia a IP incorrecta (`172.16.14.54`).
  - el nodo k3s real exponiendo NodePort `30443` era `172.16.14.185`.
- Validacion:
  - contra `172.16.14.54:30443` -> rechazado.
  - contra `172.16.14.185:30443` con `Host: apim-wso2.local` -> `HTTP 200`.
- Correccion:
  - actualizar `/etc/hosts` para apuntar dominios WSO2 a la IP del nodo k3s activo.

### 14.8 Publicacion de API desde OpenAPI remoto y doble token
- Caso implementado:
  - importacion OpenAPI desde:
    - `http://10.50.129.101:5511/v3/api-docs`

- Configuracion exacta realizada en Publisher (WSO2):
  1. `Create API` -> `Import OpenAPI` -> URL remota.
  2. Datos base:
     - `Name`: `ONPThaqhiriAPI`
     - `Version`: `1.0.0`
     - `Context`: `/onpthaqhiriapi`
  3. `Endpoints`:
     - `Production`: `http://10.50.129.101:5511`
     - `Sandbox`: `http://10.50.129.101:5511`
  4. `Runtime`:
     - seguridad de API en `OAuth2`.
     - `Authorization Header` cambiado de `Authorization` a `X-APIM-Authorization`.
  5. `Lifecycle`:
     - `Publish`.
  6. `Deployments`:
     - crear `Revision 1` y desplegar en gateway `Default`.
  7. `Subscriptions`:
     - suscribir app cliente al API con plan `Unlimited`.

- Como se habilito el esquema de doble token en WSO2:
  - problema inicial: el backend ya usa `Authorization: Bearer <token_backend>`, pero WSO2 tambien esperaba su token en `Authorization`.
  - ajuste aplicado: se cambio el header de validacion de WSO2 a `X-APIM-Authorization` (en Runtime de la API).
  - efecto:
    - WSO2 valida consumo con `X-APIM-Authorization`.
    - el header `Authorization` queda disponible para pasar el token propio al backend.
  - no se requirio plugin custom; fue configuracion nativa de WSO2 en `Runtime -> Key Manager Configuration -> Authorization Header`.

- Invocacion valida final (cliente -> APIM -> backend):
  - URL:
    - `https://api-wso2.local:30443/onpthaqhiriapi/1.0.0/api/horarios`
  - Headers:
    - `X-APIM-Authorization: Bearer <token_apim>`
    - `Authorization: Bearer <token_backend>`
  - resultado validado:
    - `200 OK` en `GET /api/horarios`.

### 14.9 Errores funcionales observados y resolucion
- Error `900902 Missing Credentials`:
  - causa: APIM no recibia credencial en el header configurado.
  - resolucion: enviar token APIM en `X-APIM-Authorization`.
- Error `900901 Invalid Credentials`:
  - causa: token APIM vencido/invalido.
  - resolucion: regenerar token por `client_credentials` en:
    - `https://apim-wso2.local:30443/oauth2/token`
- Error backend `Token invalido segun SAA`:
  - causa: token del backend invalido/no enviado.
  - resolucion: renovar y enviar `Authorization` de backend correctamente.

### 14.9.1 Caso especial: DB APIM vacia tras reinicio (sin tablas)
- Sintoma:
  - `wso2_apim_db` existe, pero `\dt` no lista tablas.
  - UI no muestra APIs previas.
- Causa:
  - el esquema no fue inicializado en `wso2_apim_db` (dbscripts no aplicados).
- Verificacion rapida:
  - `kubectl -n apim-wso2 exec -it deploy/wso2-postgres -- psql -U wso2 -d wso2_apim_db -c "\dt"`
- Correccion aplicada (PostgreSQL):
  1. Ejecutar scripts de WSO2 desde el pod de WSO2 hacia Postgres:
     - Shared DB:
       - `cat /home/wso2carbon/wso2am-4.6.0/dbscripts/postgresql.sql | psql -U wso2 -d wso2_shared_db`
     - APIM DB:
       - `cat /home/wso2carbon/wso2am-4.6.0/dbscripts/apimgt/postgresql.sql | psql -U wso2 -d wso2_apim_db`
  2. Comandos exactos en k8s:
     - `kubectl -n apim-wso2 exec -it deploy/wso2apim -- cat /home/wso2carbon/wso2am-4.6.0/dbscripts/postgresql.sql | kubectl -n apim-wso2 exec -i deploy/wso2-postgres -- psql -U wso2 -d wso2_shared_db -f /dev/stdin`
     - `kubectl -n apim-wso2 exec -it deploy/wso2apim -- cat /home/wso2carbon/wso2am-4.6.0/dbscripts/apimgt/postgresql.sql | kubectl -n apim-wso2 exec -i deploy/wso2-postgres -- psql -U wso2 -d wso2_apim_db -f /dev/stdin`
  3. Reiniciar WSO2:
     - `kubectl -n apim-wso2 rollout restart deploy wso2apim`

### 14.10 Evidencias de cierre (comandos y salida esperada)
- Estado de pods:
  - `kubectl -n apim-wso2 get pods -o wide`
  - esperado: `wso2-postgres` y `wso2apim` en `Running`.
- Estado de ingress y service:
  - `kubectl -n apim-wso2 get svc,ingress`
  - esperado: host `apim-wso2.local` y `api-wso2.local` activos.
- Endpoint Publisher:
  - `curl -skI https://<NODE_IP>:30443/publisher/ -H 'Host: apim-wso2.local'`
  - esperado: `HTTP 200`.
- Endpoint token:
  - `curl -sk -X POST 'https://apim-wso2.local:30443/oauth2/token' ...`
  - esperado: respuesta JSON con `access_token`.

### 14.11 Estado final de funcionamiento
- WSO2 APIM operativo en `apim-wso2` para flujos de Publisher y Gateway.
- Integraciones base funcionando:
  - Vault (inyeccion de secretos)
  - ingress-nginx + TLS
  - backend externo via OpenAPI remoto
- Problemas criticos resueltos:
  - orden de init con Vault
  - backend protocol HTTPS en ingress
  - redirects a localhost
  - `1/2 Ready` por startup transitorio
  - DNS/hosts apuntando a IP incorrecta

### 14.12 Guia operativa rapida (WSO2)
- URLs de uso en esta PoC:
  - Publisher: `https://apim-wso2.local:30443/publisher`
  - Dev Portal: `https://apim-wso2.local:30443/devportal`
  - Gateway base: `https://api-wso2.local:30443`
- Credenciales iniciales validadas:
  - `admin / admin` (en esta instalacion).
- Flujo de prueba aplicado para API con autenticacion dual:
  1. Generar token APIM (OAuth2 `client_credentials`).
  2. Generar token propio del backend (servicio SAA).
  3. Invocar API por gateway WSO2 enviando:
     - `X-APIM-Authorization: Bearer <token_apim>`
     - `Authorization: Bearer <token_backend>`
- Motivo tecnico:
  - WSO2 valida primero su token de consumo.
  - El backend mantiene su validacion funcional de negocio con su token propio.

### 14.13 Referencia al anexo base transversal
- Para detalle tecnico profundo de red/firewall, Vault e ingress-nginx (con troubleshooting y comandos de diagnostico), ver:
  - `## 15) Anexo tecnico base - Firewall, Vault e Ingress NGINX`
- Este anexo base aplica a WSO2 y Gravitee y centraliza operacion/soporte para evitar duplicidad en la bitacora.

## 15) Anexo tecnico base - Firewall, Vault e Ingress NGINX
### 15.1 Firewall del host (Ubuntu 24)
- Objetivo:
  - permitir acceso desde la red LAN a los NodePort HTTPS usados por los APIM.
- Puertos requeridos en esta PoC:
  - `30443/tcp` (WSO2 via ingress-nginx)
  - `31443/tcp` (Gravitee via ingress-nginx)
- Comandos de configuracion (`ufw`):
  - `sudo ufw allow 30443/tcp comment 'k3s ingress HTTPS WSO2'`
  - `sudo ufw allow 31443/tcp comment 'k3s ingress HTTPS Gravitee'`
  - `sudo ufw reload`
  - `sudo ufw status numbered`
- Validacion desde otra PC:
  - `curl -kI https://<IP_NODO>:30443`
  - `curl -kI https://<IP_NODO>:31443`
- Nota:
  - si `ufw` no esta habilitado: `sudo ufw enable`.
  - en hosts con politicas nftables/iptables personalizadas, revisar tambien:
    - `sudo nft list ruleset`
    - `sudo iptables -S`

### 15.1.1 Diagnostico de conectividad (paso a paso)
- 1) validar resolucion de nombres:
  - `getent hosts apim-wso2.local api-wso2.local apim-gravitee.local api-gravitee.local`
- 2) validar puerto abierto en host local:
  - `nc -vz <IP_NODO> 30443`
  - `nc -vz <IP_NODO> 31443`
- 3) validar handshake y ruteo por host header:
  - `curl -vkI https://<IP_NODO>:30443/publisher/ -H 'Host: apim-wso2.local'`
  - `curl -vkI https://<IP_NODO>:31443/console -H 'Host: apim-gravitee.local'`
- 4) validar listeners del nodo:
  - `ss -lntp | rg '30080|30443|31443|6443'`
- Matriz rapida de causa raiz:
  - FQDN falla y `IP_NODO` funciona -> problema DNS/`/etc/hosts`.
  - ambos fallan con timeout/refused -> firewall/ruteo host o servicio ingress no expuesto.
  - `IP_NODO` responde pero devuelve 404 inesperado -> host header/path incorrecto.

### 15.2 Ingress NGINX (separacion de puertos por APIM)
- Diseno aplicado:
  - mismo controlador `ingress-nginx`, dos NodePort HTTPS expuestos.
- Estado esperado de servicio:
  - `80:30080/TCP`
  - `443:30443/TCP`
  - `444:31443/TCP`
- Comando de verificacion:
  - `kubectl -n ingress-nginx get svc ingress-nginx-controller`
- Verificacion detallada del Service:
  - `kubectl -n ingress-nginx get svc ingress-nginx-controller -o yaml`
  - esperado:
    - `name: https`, `port: 443`, `nodePort: 30443`
    - `name: https-alt`, `port: 444`, `nodePort: 31443`
- Verificacion de rutas por host header:
  - WSO2 Publisher:
    - `curl -skI https://<IP_NODO>:30443/publisher/ -H 'Host: apim-wso2.local'`
  - Gravitee Console:
    - `curl -skI https://<IP_NODO>:31443/console -H 'Host: apim-gravitee.local'`
- Verificacion de Ingress por namespace:
  - `kubectl -n apim-wso2 get ingress -o wide`
  - `kubectl -n apim-gravitee get ingress -o wide`
- Troubleshooting tipico:
  - si aparece `502 connect() failed (111: Connection refused)` en controller logs:
    - validar que backend pod este `Ready`.
    - validar `targetPort` correcto en Service.
    - en WSO2, validar `nginx.ingress.kubernetes.io/backend-protocol: "HTTPS"` en ambos ingress.
- Logs de referencia:
  - `kubectl -n ingress-nginx logs deploy/ingress-nginx-controller --tail=300 | rg 'apim-wso2|api-wso2|apim-gravitee|api-gravitee|502|upstream'`
- Artefacto tecnico relacionado:
  - `manual/manifests/ingress/60-service.yaml`.

### 15.3 Vault (operacion tecnica para continuidad)
- Estado y componentes:
  - namespace `vault` con servidor y `vault-agent-injector`.
- Verificacion de estado:
  - `kubectl -n vault get pods`
  - `kubectl -n vault exec -it vault-0 -- vault status`
- Si Vault aparece `sealed`:
  1. ingresar al pod:
     - `kubectl -n vault exec -it vault-0 -- sh`
  2. ejecutar unseal (3 de 5 llaves):
     - `vault operator unseal <UNSEAL_KEY_1>`
     - `vault operator unseal <UNSEAL_KEY_2>`
     - `vault operator unseal <UNSEAL_KEY_3>`
  3. confirmar:
     - `vault status` con `Sealed: false`.
- Secretos usados por APIMs (referencia):
  - WSO2: `kv/apim/wso2/*`
  - Gravitee: `kv/apim/gravitee/*`
- Verificacion de auth/roles Kubernetes:
  - `kubectl -n vault exec -it vault-0 -- vault read auth/kubernetes/config`
  - `kubectl -n vault exec -it vault-0 -- vault read auth/kubernetes/role/apim-wso2`
  - `kubectl -n vault exec -it vault-0 -- vault read auth/kubernetes/role/apim-gravitee`
- Verificacion de inyeccion en pods APIM:
  - `kubectl -n apim-wso2 describe pod <wso2apim-pod> | rg 'vault.hashicorp.com|Init Containers|vault-agent-init|render-config'`
  - `kubectl -n apim-gravitee describe pod <pod> | rg 'vault.hashicorp.com|Init Containers|vault-agent-init'`
- Troubleshooting tipico de Vault injection:
  - `permission denied` leyendo secretos:
    - validar policy/role y `bound_service_account_namespaces`.
  - `render-config` falla por archivos faltantes:
    - validar `vault.hashicorp.com/agent-init-first: "true"` y templates.
  - restart loops por Vault temporalmente no disponible:
    - revisar estado `vault-0` y health del injector.
- Comando de prueba funcional de secretos (desde Vault):
  - `kubectl -n vault exec -it vault-0 -- vault kv get kv/apim/wso2/admin`
- Nota de seguridad:
  - llaves de unseal y root token fuera de repositorio, en almacenamiento seguro.

### 15.4 Caso real aplicado en esta PoC (WSO2 no cargaba UI)
- Sintoma:
  - `https://apim-wso2.local:30443/publisher/` sin respuesta.
- Hallazgo:
  - `apim-wso2.local` apuntaba a `172.16.14.54` y el nodo real era `172.16.14.185`.
- Validacion que cerro incidente:
  - `curl -vkI https://172.16.14.185:30443/publisher/ -H 'Host: apim-wso2.local'` -> `HTTP 200`.
- Accion correctiva:
  - corregir `/etc/hosts` hacia IP real del nodo k3s.

### 15.5 Checklist de cierre operativo (base)
- `kubectl -n ingress-nginx get svc ingress-nginx-controller` con `30443` y `31443` presentes.
- `kubectl -n vault get pods` con Vault e injector en `Running`.
- `kubectl -n apim-wso2 get pods` y `kubectl -n apim-gravitee get pods` sin CrashLoop.
- `curl` por host header a Publisher WSO2 y Console Gravitee devolviendo `HTTP 200`.
- DNS local (`/etc/hosts`) alineado con IP real del nodo.
