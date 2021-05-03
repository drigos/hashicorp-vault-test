#!/bin/bash


function userpass_create_role() {
  local auth_path=$1
  local role_path=$2
  local policy_name=$3
  local user_id=$4
  local claim=$5

  curl -s -X POST -H "X-Vault-Token: ${ROOT_TOKEN}" -d "{ \"policies\": [\"${policy_name}\"], \"role_type\": \"jwt\", \"bound_subject\": \"${user_id}\", \"user_claim\": \"${claim}\" }" "${VAULT_ADDR}/auth/${auth_path}/role/${role_path}" > /dev/null
  echo "Configured role [${role_path}]"
}

function userpass_login() {
  local auth_path=$1
  local user=$2
  local pass=$3
  local app_token
  local bound_issuer=$4
  app_token=$(curl -s -X POST -d "{\"password\": \"${pass}\", \"bound_issuer\": \"${bound_issuer}\"}" "${VAULT_ADDR}/auth/${auth_path}/login/${user}" | jq -r '.auth.client_token')

  echo "App token: ${app_token}"

  echo "${app_token}" >&4
}

function userpass_create_user() {
  local auth_path=$1
  local user=$2
  local pass=$3
  local bound_issuer=$4

  curl -s -X POST -H "X-Vault-Token: ${ROOT_TOKEN}" -d "{\"password\": \"${pass}\", \"bound_issuer\": \"${bound_issuer}\"}" "${VAULT_ADDR}/auth/${auth_path}/users/${user}"
  echo "Created user"
}
