#!/bin/bash

VAULT_ADDR=http://127.0.0.1:8200/v1

# N unseal key > combined key > encrypted master key > encrypted kering > encrypted data

#if [ -z "${ROOT_TOKEN}" -o -z "${UNSEAL_KEY}" ];
#then
    echo 'ROOT_CREDENTIAL=$(curl -s -X POST -d '{ "secret_shares": 1, "secret_threshold": 1 }' ${VAULT_ADDR}/sys/init)'
    UNSEAL_KEY=$(echo ${ROOT_CREDENTIAL} | jq -r '.keys_base64[0]')
    ROOT_TOKEN=$(echo ${ROOT_CREDENTIAL} | jq -r '.root_token')
#fi

echo "Export this variables:"
echo "    export UNSEAL_KEY=${UNSEAL_KEY}"
echo "    export ROOT_TOKEN=${ROOT_TOKEN}"

curl -s -X POST -d "{ \"key\": \"${UNSEAL_KEY}\" }" ${VAULT_ADDR}/sys/unseal > /dev/null

echo "Initialized: $(curl -s ${VAULT_ADDR}/sys/init | jq -r '.initialized')"

SECRET_MOUNT=$(curl -s -H "X-Vault-Token: ${ROOT_TOKEN}" ${VAULT_ADDR}/sys/mounts | jq '."secret/".uuid')
test "${SECRET_MOUNT}" = "null" && curl -X POST -H "X-Vault-Token: ${ROOT_TOKEN}" -d '{ "type": "kv-v2" }' ${VAULT_ADDR}/sys/mounts/secret
echo "Secret mount: ${SECRET_MOUNT/null/created}"

echo "Policy"
sed -r 's/(.*)/    \1/g' my-policy.hcl
POLICY=$(jq -Rs '' < my-policy.hcl)
curl -s -X POST -H "X-Vault-Token: ${ROOT_TOKEN}" -d "{ \"policy\": ${POLICY} }" ${VAULT_ADDR}/sys/policies/acl/my-policy
echo "Configured policy"

echo ""
echo "AUTH TYPE: AppRole"
echo "------------------"

APPROLE_AUTH_TYPE=$(curl -s -H "X-Vault-Token: ${ROOT_TOKEN}" ${VAULT_ADDR}/sys/auth | jq '."approle/".uuid')
test "${APPROLE_AUTH_TYPE}" = "null" && curl -s -X POST -H "X-Vault-Token: ${ROOT_TOKEN}" -d '{ "type": "approle" }' ${VAULT_ADDR}/sys/auth/approle
echo "AppRole auth type: ${APPROLE_AUTH_TYPE/null/created}"

curl -s -X POST -H "X-Vault-Token: ${ROOT_TOKEN}" -d '{ "policies": ["my-policy"] }' ${VAULT_ADDR}/auth/approle/role/my-role
echo "Configured role"

ROLE_ID=$(curl -s -H "X-Vault-Token: ${ROOT_TOKEN}" ${VAULT_ADDR}/auth/approle/role/my-role/role-id | jq -r '.data.role_id')
SECRET_ID=$(curl -s -X POST -H "X-Vault-Token: ${ROOT_TOKEN}" ${VAULT_ADDR}/auth/approle/role/my-role/secret-id | jq -r '.data.secret_id')

echo "Role ID: ${ROLE_ID}"
echo "Secret ID: ${SECRET_ID}"

APP_TOKEN=$(curl -s -X POST -d "{ \"role_id\": \"${ROLE_ID}\", \"secret_id\": \"${SECRET_ID}\" }" ${VAULT_ADDR}/auth/approle/login | jq -r '.auth.client_token')

echo "App token: ${APP_TOKEN}"

echo "App: creating secret bar"
curl -s -X POST -H "X-Vault-Token: ${APP_TOKEN}" -d '{ "data": { "secret": "short-secret" } }' ${VAULT_ADDR}/secret/data/bar | jq #'.data.created_time'
echo "Root: reading secret bar"
curl -s -H "X-Vault-Token: ${ROOT_TOKEN}" ${VAULT_ADDR}/secret/data/bar | jq -c '.data'

echo "Root: creating secret foo"
curl -s -X POST -H "X-Vault-Token: ${ROOT_TOKEN}" -d '{ "data": { "secret": "my-long-long-secret" } }' ${VAULT_ADDR}/secret/data/foo | jq '.data.created_time'
echo "App: reading secret foo"
curl -s -H "X-Vault-Token: ${APP_TOKEN}" ${VAULT_ADDR}/secret/data/foo | jq -c '.data'

echo ""
echo "AUTH TYPE: JWT"
echo "--------------"

echo "Pending"
# https://stackoverflow.com/questions/64757450/how-to-set-up-vault-jwt-authentication-with-auto-auth
# curl -s -X POST -d '{ "jwt": "your_jwt", "role": "demo" }' ${VAULT_ADDR}/auth/jwt/login

echo ""
echo "AUTH TYPE: Username & Password"
echo "------------------------------"

echo "Pending"

echo ""
echo "---"

echo ""
echo "Reference: https://www.vaultproject.io/api-docs/system"

#curl -s -H "X-Vault-Token: ${ROOT_TOKEN}" ${VAULT_ADDR}/sys/auth| jq
