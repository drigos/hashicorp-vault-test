#!/bin/bash

VAULT_ADDR=http://127.0.0.1:8200/v1

# N unseal key > combined key > encrypted master key > encrypted kering > encrypted data

if [ -z "${ROOT_TOKEN}" -o -z "${UNSEAL_KEY}" ];
then
    ROOT_CREDENTIAL=$(curl -s -X POST -d '{ "secret_shares": 1, "secret_threshold": 1 }' ${VAULT_ADDR}/sys/init)
    UNSEAL_KEY=$(echo ${ROOT_CREDENTIAL} | jq -r '.keys_base64[0]')
    ROOT_TOKEN=$(echo ${ROOT_CREDENTIAL} | jq -r '.root_token')
fi

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
curl -s -X POST -H "X-Vault-Token: ${APP_TOKEN}" -d '{ "data": { "secret": "short-secret" } }' ${VAULT_ADDR}/secret/data/bar | jq '.data.created_time'
echo "Root: reading secret bar"
curl -s -H "X-Vault-Token: ${ROOT_TOKEN}" ${VAULT_ADDR}/secret/data/bar | jq -c '.data'

echo "Root: creating secret foo"
curl -s -X POST -H "X-Vault-Token: ${ROOT_TOKEN}" -d '{ "data": { "secret": "my-long-long-secret" } }' ${VAULT_ADDR}/secret/data/foo | jq '.data.created_time'
echo "App: reading secret foo"
curl -s -H "X-Vault-Token: ${APP_TOKEN}" ${VAULT_ADDR}/secret/data/foo | jq -c '.data'

echo ""
echo "AUTH TYPE: JWT"
echo "--------------"

# https://stackoverflow.com/questions/64757450/how-to-set-up-vault-jwt-authentication-with-auto-auth
# curl -s -X POST -d '{ "jwt": "your_jwt", "role": "demo" }' ${VAULT_ADDR}/auth/jwt/login

echo "App: creating jwt validation"
JWT_AUTH_ROLE=$(curl -s -H "X-Vault-Token: ${ROOT_TOKEN}" ${VAULT_ADDR}/sys/auth | jq '."jwt/".uuid')
test "${JWT_AUTH_ROLE}" = "null" && curl -s -X POST -H "X-Vault-Token: ${ROOT_TOKEN}" -d '{ "type": "jwt", "description": "Login with JWT" }' ${VAULT_ADDR}/sys/auth/jwt
echo "Jwt auth type: ${JWT_AUTH_ROLE/null/created}"

echo "System: create private key"
openssl genrsa -aes256 -passout pass:igor -out private_key.pem 2048
openssl rsa -pubout -passin pass:igor -in private_key.pem -out public_key.pem

PUBLIC_KEY=$(jq -Rs '' < public_key.pem)

echo "App: configure jwt validation"
curl -s -X POST -H "X-Vault-Token: ${ROOT_TOKEN}" -d "{\"jwt_validation_pubkeys\": ${PUBLIC_KEY}, \"bound_issuer\": \"www.soufan.com.br\"}" ${VAULT_ADDR}/auth/jwt/config | jq
echo "App: configured jwt"

echo "App: Configure role"
JWT_ROLE=curl -s -X POST -H "X-Vault-Token: ${ROOT_TOKEN}" -d '{ "policies": ["my-policy"], "role_type": "jwt", "bound_subject": "igor", "user_claim": "igor"}' ${VAULT_ADDR}/auth/jwt/role/my-role
echo "App: Role configured"

function b64enc() { openssl enc -base64 -A | tr '+/' '-_' | tr -d '='; }
function rs_sign() { openssl dgst -binary -sha256 -passin pass:igor -sign private_key.pem; }

HEADER='{
    "type": "JWT",
    "alg": "RS256"
}'

payload='{
    "igor": "igor",
	"sub": "igor",
    "iss": "www.soufan.com.br"
}'

PAYLOAD=$(
	echo "${payload}" | jq --arg time_str "$(date +%s)" \
	'
	($time_str | tonumber) as $time_num
	| .iat=$time_num
	| .exp=($time_num + 60 * 60)
	'
)

JWT_HDR_B64="$(echo -n "$HEADER" | b64enc)"
JWT_PAY_B64="$(echo -n "$PAYLOAD" | b64enc)"
UNSIGNED_JWT="$JWT_HDR_B64.$JWT_PAY_B64"
SIGNATURE=$(echo -n "$UNSIGNED_JWT" | rs_sign | b64enc)

JWT_TOKEN="$UNSIGNED_JWT.$SIGNATURE"
APP_TOKEN=$(curl -s -X POST -d "{ \"role\": \"my-role\", \"jwt\": \"${JWT_TOKEN}\" }" ${VAULT_ADDR}/auth/jwt/login | jq -r '.auth.client_token')

echo "App: creating secret bar"
curl -s -X POST -H "X-Vault-Token: ${APP_TOKEN}" -d '{ "data": { "secret": "short-secret" } }' ${VAULT_ADDR}/secret/data/bar | jq '.data.created_time'
echo "Root: reading secret bar"
curl -s -H "X-Vault-Token: ${ROOT_TOKEN}" ${VAULT_ADDR}/secret/data/bar | jq -c '.data'

echo "Root: creating secret foo"
curl -s -X POST -H "X-Vault-Token: ${ROOT_TOKEN}" -d '{ "data": { "secret": "my-long-long-secret" } }' ${VAULT_ADDR}/secret/data/foo | jq '.data.created_time'
echo "App: reading secret foo"
curl -s -H "X-Vault-Token: ${APP_TOKEN}" ${VAULT_ADDR}/secret/data/foo | jq -c '.data'

echo ""
echo "AUTH TYPE: Username & Password"
echo "------------------------------"

echo "Pending"

echo ""
echo "---"

echo ""
echo "Reference: https://www.vaultproject.io/api-docs/system"

#curl -s -H "X-Vault-Token: ${ROOT_TOKEN}" ${VAULT_ADDR}/sys/auth| jq
