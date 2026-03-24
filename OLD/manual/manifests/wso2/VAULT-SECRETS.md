# WSO2 Vault secrets esperados

Estos secrets deben existir en Vault:

- `kv/apim/wso2/db`
  - `password`: password para `wso2_shared_db` y `wso2_apim_db`

- `kv/apim/wso2/postgres`
  - `password`: password del usuario `wso2` en Postgres

- `kv/apim/wso2/admin`
  - `password`: password del admin UI

- `kv/apim/wso2/keystore`
  - `file_b64`: contenido base64 de `wso2carbon.p12`
  - `password`: password del keystore

- `kv/apim/wso2/truststore`
  - `file_b64`: contenido base64 de `client-truststore.p12`
  - `password`: password del truststore

Notas:
- Los archivos P12 se decodifican en el initContainer y se montan en
  `/home/wso2carbon/wso2-config-volume/repository/resources/security`.
- No subir secretos al repo.
