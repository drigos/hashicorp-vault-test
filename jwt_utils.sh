#!/bin/bash

function generate_certificate() {
  local certificate_name=$1
  local certificate_password=$2
  local public_key

  openssl genrsa -aes256 -passout "pass:${certificate_password}" -out "${certificate_name}-private.pem" 2048 2>/dev/null
  openssl rsa -pubout -passin "pass:${certificate_password}" -in "${certificate_name}-private.pem" -out "${certificate_name}-public.pem" 2>/dev/null

  public_key=$(jq -Rs '' <"${certificate_name}-public.pem")

  echo "Certificate [${certificate_name}-public.pem]"

  echo "${public_key}" >&4
}

function base64_encode() { openssl enc -base64 -A | tr '+/' '-_' | tr -d '='; }
function rs_sign() { openssl dgst -binary -sha256 -passin "pass:$2" -sign "$1-private.pem"; }

function jwt_sign() {
  local certificate_name=$1
  local certificate_password=$2
  local user_id=$3
  local issuer=$4
  local claim=$5

  local header='{
    "type": "JWT",
    "alg": "RS256"
  }'

  local custom_payload="{
    \"${claim}\": \"${claim}\",
  	\"sub\": \"${user_id}\",
    \"iss\": \"${issuer}\"
  }"

  local payload
  payload=$(
    echo "${custom_payload}" | jq --arg time_str "$(date +%s)" \
      '
      ($time_str | tonumber) as $time_num
      | .iat=$time_num
      | .exp=($time_num + 60 * 60)
      '
  )

  local jwt_header_b64
  local jwt_payload_b64
  jwt_header_b64=$(echo -n "${header}" | base64_encode)
  jwt_payload_b64=$(echo -n "${payload}" | base64_encode)

  unsigned_jwt=${jwt_header_b64}.${jwt_payload_b64}

  local signature
  signature=$(echo -n "${unsigned_jwt}" | rs_sign "${certificate_name}" "${certificate_password}" | base64_encode)

  local jwt_token=${unsigned_jwt}.${signature}

  echo "JWT token [${user_id}]"

  echo "${jwt_token}" >&4
}

