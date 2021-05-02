#!/bin/bash

function initialize() {
  local root_credential

  if [ -z "${ROOT_TOKEN}" ] || [ -z "${UNSEAL_KEY}" ]; then
    root_credential=$(curl -s -X POST -d '{ "secret_shares": 1, "secret_threshold": 1 }' ${VAULT_ADDR}/sys/init)
    UNSEAL_KEY=$(echo "${root_credential}" | jq -r '.keys_base64[0]')
    ROOT_TOKEN=$(echo "${root_credential}" | jq -r '.root_token')

    echo "Export this variables:"
    echo "    export UNSEAL_KEY=${UNSEAL_KEY}"
    echo "    export ROOT_TOKEN=${ROOT_TOKEN}"
  fi

  echo "Initialized: $(curl -s ${VAULT_ADDR}/sys/init | jq -r '.initialized')"
}

function unseal() {
  local seal
  seal=$(curl -s -X POST -d "{ \"key\": \"${UNSEAL_KEY}\" }" ${VAULT_ADDR}/sys/unseal | jq -r '.sealed')
  echo "Sealed: ${seal}"
}

function mount() {
  local mount_path=$1
  local secret_mount_id

  secret_mount_id=$(curl -s -H "X-Vault-Token: ${ROOT_TOKEN}" ${VAULT_ADDR}/sys/mounts | jq -r ".\"${mount_path}/\".uuid")
  test "${secret_mount_id}" = "null" && {
    curl -X POST -H "X-Vault-Token: ${ROOT_TOKEN}" -d '{ "type": "kv-v2" }' "${VAULT_ADDR}/sys/mounts/${mount_path}"
    secret_mount_id=$(curl -s -H "X-Vault-Token: ${ROOT_TOKEN}" ${VAULT_ADDR}/sys/mounts | jq -r ".\"${mount_path}/\".uuid")
  }
  echo "Secret mount [${mount_path}]: ${secret_mount_id}"
}

