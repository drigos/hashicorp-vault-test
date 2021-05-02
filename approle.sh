#!/bin/bash

function approle_create_role() {
  local auth_path=$1
  local role_path=$2
  local policy_name=$3
  local role_id
  local secret_id

  curl -s -X POST -H "X-Vault-Token: ${ROOT_TOKEN}" -d "{ \"policies\": [\"${policy_name}\"] }" "${VAULT_ADDR}/auth/${auth_path}/role/${role_path}"
  echo "Configured role [${role_path}]"

  role_id=$(curl -s -H "X-Vault-Token: ${ROOT_TOKEN}" "${VAULT_ADDR}/auth/${auth_path}/role/${role_path}/role-id" | jq -r '.data.role_id')
  secret_id=$(curl -s -X POST -H "X-Vault-Token: ${ROOT_TOKEN}" "${VAULT_ADDR}/auth/${auth_path}/role/${role_path}/secret-id" | jq -r '.data.secret_id')

  echo "    Role ID: ${role_id}"
  echo "    Secret ID: ${secret_id}"

  echo "${role_id} ${secret_id}" >&4
}

function approle_login() {
  local auth_path=$1
  local role_id=$2
  local secret_id=$3
  local app_token

  app_token=$(curl -s -X POST -d "{ \"role_id\": \"${role_id}\", \"secret_id\": \"${secret_id}\" }" "${VAULT_ADDR}/auth/${auth_path}/login" | jq -r '.auth.client_token')

  echo "App token: ${app_token}"

  echo "${app_token}" >&4
}

