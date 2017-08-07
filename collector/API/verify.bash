#!/usr/bin/env bash
token=$1
publickey=$2

# JWT uses base64URL NOT base64
function decode {
  declare INPUT=${1:-$(</dev/stdin)}
  length=$((${#INPUT} % 4))
  if [ $length -eq 2 ]; then tmp="$INPUT"'=='
  elif [ $length -eq 3 ]; then tmp="$INPUT"'='
  else tmp="$INPUT" ; fi
  echo -n "$tmp" | tr '_-' '/+' | base64 -D
  #openssl enc -d -a -A
}

echo -n $(cat "$token" | cut -f3 -d.) | decode > token.bin
echo -n $(cat "$token" | cut -f1,2 -d.) > token.txt
echo "$(openssl dgst -sha256 -verify "$publickey" -signature token.bin token.txt)"

echo -n $(cat "$token" | cut -f1 -d.) | decode | jq .
echo -n $(cat "$token" | cut -f2 -d.) | decode | jq .
