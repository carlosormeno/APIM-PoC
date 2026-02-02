# Vault – Guía rápida PoC

## 1) Instalación (prod-like en PoC)
```bash
helm repo add hashicorp https://helm.releases.hashicorp.com
helm repo update
kubectl create ns vault

helm upgrade --install vault hashicorp/vault -n vault -f vault/vault-values.yaml
```

## 2) Init + Unseal
```bash
kubectl exec -n vault -it vault-0 -- vault operator init -key-shares=3 -key-threshold=2
kubectl exec -n vault -it vault-0 -- vault operator unseal <unseal_key_1>
kubectl exec -n vault -it vault-0 -- vault operator unseal <unseal_key_2>
```

## 3) Dónde guardar claves y tokens
- Guardar **unseal keys** y **root token** en un gestor seguro (ej. bóveda corporativa).
- Documentar en el kit de evidencias **que se ejecutó init/unseal**, pero **no almacenar llaves en el repo**.

## 4) Auth Kubernetes (resumen)
```bash
vault auth enable kubernetes
vault write auth/kubernetes/config \
  token_reviewer_jwt="<jwt>" \
  kubernetes_host="https://<k8s-api>" \
  kubernetes_ca_cert=@/var/run/secrets/kubernetes.io/serviceaccount/ca.crt
```

## 5) Policies y secrets (ejemplo)
```bash
vault policy write apim-gravitee - <<'POL'
path "kv/apim/gravitee/*" { capabilities = ["read"] }
POL

vault kv put kv/apim/gravitee/admin password="changeme"
```
