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
IFS=$'\n\t'

HEADER='{
    "typ": "JWT",
    "alg": "RS256",
    "kid": "0001",
    "iss": "'$email' Bash JWT Generator",
    "exp": '$(($(date +%s)+exp))',
    "iat": '$(date +%s)'
}'

PAYLOAD="{
    \"nonce\": \"$nonce\",
    \"email\":\"$email\"
}"

function base64_encode()
{
    declare INPUT=${1:-$(</dev/stdin)}
    echo -n "${INPUT}" | openssl enc -base64 -A
}

function base64_decode()
{
    declare INPUT=${1:-$(</dev/stdin)}
    echo -n "${INPUT}" | openssl enc -base64 -d -A
}

function json() {
    declare INPUT=${1:-$(</dev/stdin)}
    echo -n "${INPUT}" | jq -c .
}

function RSAsha256_sign()
{
    declare INPUT=${1:-$(</dev/stdin)}
    echo -n "${INPUT}" | openssl dgst -binary -sha256 -sign privatekey.pem
}

HEADER_BASE64=$(echo "${HEADER}" | json | base64_encode)
PAYLOAD_BASE64=$(echo "${PAYLOAD}" | json | base64_encode)

HEADER_PAYLOAD=$(echo "${HEADER_BASE64}.${PAYLOAD_BASE64}")
SIGNATURE=$(echo "${HEADER_PAYLOAD}" | tee hp.txt |  RSAsha256_sign | tee s.bin | base64_encode)

echo "${HEADER_PAYLOAD}.${SIGNATURE}" > token

echo "${HEADER_PAYLOAD}" > file.txt
openssl dgst -binary -sha256 -sign privatekey.pem -out signature.sign file.txt
openssl dgst -sha256 -verify publickey.pem -signature signature.sign file.txt
cat signature.sign | base64_encode > signature.sign.txt
#----
echo "echo"
echo "${HEADER_PAYLOAD}" | openssl dgst -binary -sha256 -sign privatekey.pem -out echo.sign
diff echo.sign signature.sign | wc -l
cat echo.sign | base64_encode > echo.sign.txt
# --
echo "file"
echo "${HEADER_PAYLOAD}" | openssl dgst -binary -sha256 -sign privatekey.pem > file.sign
diff file.sign signature.sign | wc -l
cat file.sign | base64_encode > file.sign.txt

#echo "var"
#var=$(echo "${HEADER_PAYLOAD}" | openssl dgst -binary -sha256 -sign privatekey.pem | openssl enc -base64 -A)
#echo $var > var.sign.txt
#diff var.sign.txt signature.sign.txt | wc -l


echo "---"
echo $(openssl dgst -sha256 -verify public.pem -signature s.bin hp.txt)
echo "---"
cat signature.sign.txt
echo ""
cat token | cut -f3 -d.
