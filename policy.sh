#!/bin/bash

function create_policy() {
  local policy_path=$1
  local policy_file=$2
  local mount_path=$3
  local policy_blob

  policy_blob=$(jq -Rs '' < "${policy_file}" | sed "s@secret/data@${mount_path}/data@g")
  curl -s -X POST -H "X-Vault-Token: ${ROOT_TOKEN}" -d "{ \"policy\": ${policy_blob} }" "${VAULT_ADDR}/sys/policies/acl/${policy_path}"
  echo "Policy [${policy_path}]"
  sed -r 's/(.*)/    \1/g' "${policy_file}"
}

