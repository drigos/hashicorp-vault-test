#!/bin/bash

source jwt_utils.sh

function jwt_configure() {
  local auth_path=$1
  local public_key=$2
  local bound_issuer=$3

  curl -s -X POST -H "X-Vault-Token: ${ROOT_TOKEN}" -d "{\"jwt_validation_pubkeys\": ${public_key}, \"bound_issuer\": \"${bound_issuer}\"}" "${VAULT_ADDR}/auth/${auth_path}/config"
  echo "Configured JWT"
}

function jwt_create_role() {
  local auth_path=$1
  local role_path=$2
  local policy_name=$3
  local user_id=$4
  local claim=$5

  curl -s -X POST -H "X-Vault-Token: ${ROOT_TOKEN}" -d "{ \"policies\": [\"${policy_name}\"], \"role_type\": \"jwt\", \"bound_subject\": \"${user_id}\", \"user_claim\": \"${claim}\" }" "${VAULT_ADDR}/auth/${auth_path}/role/${role_path}" > /dev/null
  echo "Configured role [${role_path}]"
}

function jwt_login() {
  local auth_path=$1
  local role_path=$2
  local jwt_token=$3
  local app_token

  app_token=$(curl -s -X POST -d "{ \"role\": \"${role_path}\", \"jwt\": \"${jwt_token}\" }" "${VAULT_ADDR}/auth/${auth_path}/login" | jq -r '.auth.client_token')

  echo "App token: ${app_token}"

  echo "${app_token}" >&4
}

