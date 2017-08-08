#!/usr/bin/env bash


usage(){
	echo "Usage: $0 token publickey"
	exit 1
}

token=$1
publickey=$2
[ -z "$token" ] && usage
[ -z "$publickey" ] && usage


set -euo pipefail

# JWT uses base64URL NOT base64
function base64url_decode {
  declare INPUT=${1:-$(</dev/stdin)}
  length=$((${#INPUT} % 4))
  if [ $length -eq 2 ]; then tmp="$INPUT"'=='
  elif [ $length -eq 3 ]; then tmp="$INPUT"'='
  else tmp="$INPUT" ; fi
  echo -n "$tmp" | tr '_-' '/+' | base64 -D
  #openssl enc -d -a -A
}

echo -n $(cat "$token" | cut -f3 -d.) | base64url_decode > token.bin
echo -n $(cat "$token" | cut -f1,2 -d.) > token.txt
echo "BASH $(openssl dgst -sha256 -verify "$publickey" -signature token.bin token.txt) $(cat "$token" | cut -f2 -d.| base64url_decode |jq -c .)"

#echo -n $(cat "$token" | cut -f1 -d.) | base64url_decode | jq .
#echo -n $(cat "$token" | cut -f2 -d.) | base64url_decode | jq .
