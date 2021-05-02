#!/bin/bash

function enable_auth_type() {
  local auth_path=$1
  local auth_type=$2
  local auth_type_id

  auth_type_id=$(curl -s -H "X-Vault-Token: ${ROOT_TOKEN}" ${VAULT_ADDR}/sys/auth | jq -r ".\"${auth_path}/\".uuid")
  test "${auth_type_id}" = "null" && {
    curl -s -X POST -H "X-Vault-Token: ${ROOT_TOKEN}" -d "{ \"type\": \"${auth_type}\" }" "${VAULT_ADDR}/sys/auth/${auth_path}"
    auth_type_id=$(curl -s -H "X-Vault-Token: ${ROOT_TOKEN}" ${VAULT_ADDR}/sys/auth | jq -r ".\"${auth_path}/\".uuid")
  }
  echo "Auth type [${auth_path}]: ${auth_type_id}"
}

function token_test() {
  local mount_path=$1
  local app_token=$2

  echo ""
  echo "Testing..."

  echo "App: creating secret bar"
  curl -s -X POST -H "X-Vault-Token: ${app_token}" -d '{ "data": { "secret": "short-secret" } }' "${VAULT_ADDR}/${mount_path}/data/bar" | jq '.data.created_time'
  echo "Root: reading secret bar"
  curl -s -H "X-Vault-Token: ${ROOT_TOKEN}" "${VAULT_ADDR}/${mount_path}/data/bar" | jq -c '.data.data'

  echo "Root: creating secret foo"
  curl -s -X POST -H "X-Vault-Token: ${ROOT_TOKEN}" -d '{ "data": { "secret": "my-long-long-secret" } }' "${VAULT_ADDR}/${mount_path}/data/foo" | jq '.data.created_time'
  echo "App: reading secret foo"
  curl -s -H "X-Vault-Token: ${app_token}" "${VAULT_ADDR}/${mount_path}/data/foo" | jq -c '.data.data'
}

