#!/bin/bash

function userpass_create_user() {
  local auth_path=$1
  local user=$2
  local pass=$3
  local bound_issuer=$4
  local policy_name=$5

  curl -s -X POST -H "X-Vault-Token: ${ROOT_TOKEN}" -d "{\"password\": \"${pass}\", \"policies\": [\"${policy_name}\"], \"bound_issuer\": \"${bound_issuer}\"}" "${VAULT_ADDR}/auth/${auth_path}/users/${user}"
  echo "Configured user [${user}]"
}

function userpass_login() {
  local auth_path=$1
  local user=$2
  local pass=$3
  local bound_issuer=$4
  local app_token
  app_token=$(curl -s -X POST -d "{\"password\": \"${pass}\", \"bound_issuer\": \"${bound_issuer}\"}" "${VAULT_ADDR}/auth/${auth_path}/login/${user}" | jq -r '.auth.client_token')

  echo "App token: ${app_token}"

  echo "${app_token}" >&4
}

