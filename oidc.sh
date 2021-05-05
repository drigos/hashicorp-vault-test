function oidc_configure() {
  local oidc_discovery_url=$1
  local auth_path=$2
  local oidc_client_id=$3
  local oidc_client_secret=$4
  local role=$5
  curl -s -X POST -H "X-Vault-Token: ${ROOT_TOKEN}" --data "{\"oidc_discovery_url\": \"${oidc_discovery_url}\", \"role_type\": \"${auth_path}\", \"oidc_client_id\": \"${oidc_client_id}\", \"oidc_client_secret\": \"${oidc_client_secret}\", \"default_role\": \"${role}\"}" $VAULT_ADDR/auth/oidc/config
  echo "App: Configured OIDC"
}

function oidc_role_configure() {
  # bound_audiences = oidc_client_id
  # policies = role_path
  local oidc_client_id=$1
  local allowed_redirect_uris=$2
  local oidc_scopes=$3
  local role_type=$4
  local user_claim=$5
  local role_path=$6
  local ttl=$7

  curl -s -X POST -H "X-Vault-Token: ${ROOT_TOKEN}" --data "{\"bound_audiences\": \"${oidc_client_id}\", \"allowed_redirect_uris\":${allowed_redirect_uris}, \"oidc_scopes\": \"${oidc_scopes}\", \"role_type\": \"${role_type}\", \"user_claim\": \"${user_claim}\", \"policies\": \"${role_path}\", \"ttl\": \"${ttl}\"}" $VAULT_ADDR/auth/oidc/role/${role_path}
  echo "App: Configured OIDC role"
}
