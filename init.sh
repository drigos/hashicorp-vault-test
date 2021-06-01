#!/bin/bash

VAULT_ADDR=http://127.0.0.1:8200/v1

IO_FILE=$(mktemp --suffix vault)
exec 3<"${IO_FILE}"
exec 4>"${IO_FILE}"

source utils.sh
source setup.sh
source policy.sh

source approle.sh
source jwt.sh
source user_pass.sh
source oidc.sh

# N unseal key (shamir) > combined key > encrypted master key > encrypted keyring > encrypted data

MOUNT_PATH=my-secret
POLICY_PATH=my-policy
POLICY_FILE=my-policy.hcl

function setup() {
  printf "\n> Setup\n\n"

  initialize
  unseal
  mount "${MOUNT_PATH}"
}

function policy() {
  printf "\n> Policies\n\n"

  create_policy "${POLICY_PATH}" "${POLICY_FILE}" "${MOUNT_PATH}"
}

function approle() {
  printf "\n> AUTH TYPE: AppRole\n\n"

  local auth_path=my-approle
  local role_path=my-role
  local role_id
  local secret_id
  local app_token

  enable_auth_type "${auth_path}" approle
  approle_create_role "${auth_path}" "${role_path}" "${POLICY_PATH}"
  read -r role_id secret_id <&3
  approle_login "${auth_path}" "${role_id}" "${secret_id}"
  read -r app_token <&3
  token_test "${MOUNT_PATH}" "${app_token}"
}

function jwt() {
  printf "\n> AUTH TYPE: JWT\n\n"
  # https://stackoverflow.com/questions/64757450/how-to-set-up-vault-jwt-authentication-with-auto-auth

  local auth_path=my-jwt
  local role_path=my-role
  local certificate_name=my-certificate
  local certificate_pass=123456
  local user_id=igor
  local issuer=www.domain.com
  local jwt_claim=general
  local public_key
  local jwt_token
  local app_token

  generate_certificate "${certificate_name}" "${certificate_pass}"
  read -r public_key <&3
  jwt_sign "${certificate_name}" "${certificate_pass}" "${user_id}" "${jwt_issuer}" "${jwt_claim}"
  read -r jwt_token <&3

  enable_auth_type "${auth_path}" jwt
  jwt_configure "${auth_path}" "${public_key}" "${jwt_issuer}"
  jwt_create_role "${auth_path}" "${role_path}" "${POLICY_PATH}" "${user_id}" "${jwt_claim}"
  jwt_login "${auth_path}" "${role_path}" "${jwt_token}"
  read -r app_token <&3
  token_test "${MOUNT_PATH}" "${app_token}"
}

function userpass() {
  printf "\n> AUTH TYPE: User & Password\n\n"

  local auth_path=my-userpass
  local role_path=my-role
  local user=igor
  local pass=123456
  local jwt_issuer=www.domain.com
  local app_token

  enable_auth_type "${auth_path}" userpass
  userpass_create_user "${auth_path}" "${user}" "${pass}" "${issuer}" "${POLICY_PATH}"
  userpass_login "${auth_path}" "${user}" "${pass}" "${issuer}"
  read -r app_token <&3
  token_test "${MOUNT_PATH}" "${app_token}"
}

function gitlab_oidc() {
  # https://docs.gitlab.com/ce/integration/vault.html
  # https://www.vaultproject.io/docs/auth/jwt#oidc-authentication
  printf "\n> AUTH TYPE: Gitlab\n\n"

  local auth_path=my-oidc
  local role_path=my-role
  local oidc_discovery_uri=https://gitlab.com
  local issuer=www.domain.com
  local role_type=oidc
  # Needs to be configured in GitLab
  local oidc_client_id=${GITLAB_APPLICATION_ID}
  local oidc_client_secret=${GITLAB_SECRET}
  local allowed_redirect_uris="[\"http://localhost:8200/ui/vault/auth/${auth_path}/oidc/callback\", \"http://localhost:8250/oidc/callback\"]"
  # Allow access only to members this group
  local bound_claim=soufan/drafts

  enable_auth_type "${auth_path}" oidc
  oidc_configure "${auth_path}" "${oidc_discovery_uri}" "${oidc_client_id}" "${oidc_client_secret}" "${role_path}" "${issuer}"
  oidc_create_role "${auth_path}" "${role_path}" "${role_type}" "${oidc_client_id}" "${allowed_redirect_uris}" "${bound_claim}" "${POLICY_PATH}"
}

function main() {
  setup
  policy
  approle
  jwt
  userpass
  gitlab_oidc
}

main
