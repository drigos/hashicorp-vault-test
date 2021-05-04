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

# N unseal key > combined key > encrypted master key > encrypted keyring > encrypted data

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
  local jwt_issuer=www.domain.com
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
  printf "\n> AUTH TYPE: USER AND PASSWORD\n\n"
  # https://stackoverflow.com/questions/64757450/how-to-set-up-vault-jwt-authentication-with-auto-auth

  local auth_path=userpass
  local role_path=my-role
  local user=igor
  local pass=123456
  local jwt_issuer=www.domain.com
  local app_token

  enable_auth_type "${auth_path}" userpass
  userpass_create_user "${auth_path}" "${user}" "${pass}" "${jwt_issuer}" "${POLICY_PATH}"
  userpass_login "${auth_path}" "${user}" "${pass}" "${jwt_issuer}"
  read -r app_token <&3
  token_test "${MOUNT_PATH}" "${app_token}"
}

function github_auth(){
  # https://docs.gitlab.com/ce/integration/vault.html
  # https://learn.hashicorp.com/tutorials/vault/getting-started-authentication
  # https://www.vaultproject.io/docs/auth/jwt#redirect-uris
  # https://www.vaultproject.io/api-docs/auth/jwt
  echo
}

function main() {
  setup
  policy
  approle
  jwt
  userpass
}

main
