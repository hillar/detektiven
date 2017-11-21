#!/usr/bin/env bash

usage(){
	echo "Usage: $0 nonce email exp privatkey publickey"
	exit 1
}

nonce=$1
email=$2
exp=$3
privatekey=$4
publickey=$5

[ -z "$nonce" ] && usage
[ -z "$email" ] && usage
[ -z "$exp" ] && usage
[ -z "$privatekey" ] && usage

set -euo pipefail
IFS=$'\n\t'

HEADER='{
    "typ": "JWT",
    "alg": "RS256",
    "kid": "0001",
    "iss": "'$email' Bash JWT Generator",
    "exp": '$(($(date +%s)+exp))',
    "iat": '$(date +%s)'
}'

PAYLOAD='{
    "nonce": "'$nonce'",
    "email":"'$email'"
}'

HEADER_BASE64=$(echo "${HEADER}" | jq -c . | openssl enc -base64 -A)
PAYLOAD_BASE64=$(echo "${PAYLOAD}" | jq -c . | openssl enc -base64 -A)

HEADER_PAYLOAD=$(echo "${HEADER_BASE64}.${PAYLOAD_BASE64}")
SIGNATURE=$(echo "${HEADER_PAYLOAD}" | tee hp.txt |  openssl dgst -binary -sha256 -sign $privatekey | tee s.bin | openssl enc -base64 -A)

echo "${HEADER_PAYLOAD}.${SIGNATURE}" > token

echo "${HEADER_PAYLOAD}" > file.txt
openssl dgst -binary -sha256 -sign "$privatekey" -out signature.sign file.txt
openssl dgst -sha256 -verify $publickey -signature signature.sign file.txt
cat signature.sign | openssl enc -base64 -A > signature.sign.txt
#----
echo "echo"
echo "${HEADER_PAYLOAD}" | openssl dgst -binary -sha256 -sign $privatekey -out echo.sign
openssl dgst -sha256 -verify $publickey -signature echo.sign file.txt
diff echo.sign signature.sign | wc -l
cat echo.sign | openssl enc -base64 -A > echo.sign.txt
# --
echo "file"
echo "${HEADER_PAYLOAD}" | openssl dgst -binary -sha256 -sign $privatekey > file.sign
openssl dgst -sha256 -verify $publickey -signature file.sign file.txt
diff file.sign signature.sign | wc -l
cat file.sign | openssl enc -base64 -A > file.sign.txt

#echo "var"
#var=$(echo "${HEADER_PAYLOAD}" | openssl dgst -binary -sha256 -sign privatekey.pem | openssl enc -base64 -A)
#echo $var > var.sign.txt
#diff var.sign.txt signature.sign.txt | wc -l


echo "---"
echo "$(openssl dgst -sha256 -verify $publickey -signature s.bin hp.txt)"
echo "---"
cat token | cut -f3 -d. | openssl enc -base64 -d -A > token.bin
cat token | cut -f1,2 -d. > token.txt
echo "$(openssl dgst -sha256 -verify $publickey -signature token.bin token.txt)"

echo "------"
cat token
