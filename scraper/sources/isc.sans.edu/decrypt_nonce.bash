#!/usr/bin/env bash

set -euo pipefail
IFS=$'\n\t'

function base64url_decode {
  declare INPUT=${1:-$(</dev/stdin)}
  length=$((${#INPUT} % 4))
  if [ $length -eq 2 ]; then tmp="$INPUT"'=='
  elif [ $length -eq 3 ]; then tmp="$INPUT"'='
  else tmp="$INPUT" ; fi
  echo -n "$tmp" | tr '_-' '/+' | base64 -D
  #openssl enc -d -a -A
}
cat $1 | base64url_decode > binarytext
openssl rsautl -decrypt -in binarytext -inkey private.pem
