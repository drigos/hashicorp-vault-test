function oidc_configure() {
  local auth_path=$1
  local oidc_discovery_uri=$2
  local oidc_client_id=$3
  local oidc_client_secret=$4
  local default_role=$5
  local bound_issuer=$6

  curl -s -X POST -H "X-Vault-Token: ${ROOT_TOKEN}" -d "{\"oidc_discovery_url\": \"${oidc_discovery_uri}\", \"oidc_client_id\": \"${oidc_client_id}\", \"oidc_client_secret\": \"${oidc_client_secret}\", \"default_role\": \"${default_role}\", \"bound_issuer\": \"${bound_issuer}\"}" "${VAULT_ADDR}/auth/${auth_path}/config"
  echo "Configured OIDC"
}

function oidc_create_role() {
  local auth_path=$1
  local role_path=$2
  local role_type=$3
  local oidc_client_id=$4
  local allowed_redirect_uris=$5
  local bound_claim=$6
  local policy_name=$7
  local oidc_scopes=openid
  local user_claim=sub
  local ttl=1h

  curl -s -X POST -H "X-Vault-Token: ${ROOT_TOKEN}" -d "{\"role_type\": \"${role_type}\", \"bound_audiences\": \"${oidc_client_id}\", \"allowed_redirect_uris\": ${allowed_redirect_uris}, \"policies\": [\"${policy_name}\"], \"oidc_scopes\": \"${oidc_scopes}\", \"user_claim\": \"${user_claim}\", \"ttl\": \"${ttl}\", \"bound_claims\": { \"groups\": [\"${bound_claim}\"] } }" "${VAULT_ADDR}/auth/${auth_path}/role/${role_path}" > /dev/null
  echo "Configured role [${role_path}]"
}
