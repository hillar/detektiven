#!/usr/bin/env bash
usage(){
	echo "Usage: $0 nonce email exp privatkey"
	exit 1
}

nonce=$1
email=$2
exp=$3
privatekey=$4

[ -z "$nonce" ] && usage
[ -z "$email" ] && usage
[ -z "$exp" ] && usage
[ -z "$privatekey" ] && usage

set -euo pipefail

function base64url_encode {
  declare INPUT=${1:-$(</dev/stdin)}
  echo -n "$INPUT" | base64 | tr -d '=' | tr '/+' '_-'
	# openssl enc -a -A
}

HEADER='{
    "typ": "JWT",
    "alg": "RS256"
}'

PAYLOAD='{
    "nonce": "'$nonce'",
    "email":"'$email'",
		"exp": '$(($(date +%s)+exp))',
		"iat": '$(date +%s)'
}'

HEADER_BASE64=$(echo -n "${HEADER}" | jq -c . | base64url_encode)
PAYLOAD_BASE64=$(echo -n "${PAYLOAD}" | jq -c . | base64url_encode)

HEADER_PAYLOAD=$(echo -n "${HEADER_BASE64}.${PAYLOAD_BASE64}")
#SIGNATURE=$(echo -n "${HEADER_PAYLOAD}" | tee hp.txt |  openssl dgst -binary -sha256 -sign $privatekey  | tee s.bin | base64url_encode)
echo -n "${HEADER_PAYLOAD}" | openssl dgst -binary -sha256 -sign $privatekey > signature.bin
SIGNATURE=$(cat signature.bin | base64 | tr -d '=' | tr '/+' '_-')

echo "${HEADER_PAYLOAD}.${SIGNATURE}"
