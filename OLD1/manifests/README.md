# Manifests renderizados (Helm → YAML)

Objetivo: tener el **mejor de ambos mundos**.
- **Helm** para parametrizar y renderizar.
- **YAML estático** versionado para trazabilidad y despliegue con `kubectl apply`.

## Flujo recomendado
1) Mantener `values.yaml` en `APIM/<producto>/values.yaml`.
2) Renderizar con `helm template` y guardar en `manifests/<producto>/`.
3) Aplicar con `kubectl apply -f manifests/<producto>/`.
4) Registrar en evidencias el commit y la fecha de render.

## Ejemplo
```bash
helm template gravitee gravitee/apim \
  -n apim-gravitee \
  -f APIM/gravitee/values.yaml \
  > manifests/gravitee/rendered.yaml

kubectl apply -f manifests/gravitee/rendered.yaml
```

> Nota: si cambias `values.yaml`, debes re‑renderizar y versionar el nuevo YAML.
