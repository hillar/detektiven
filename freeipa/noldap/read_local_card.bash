#!/bin/bash

git clone https://github.com/hillar/esteid.js.git
cd esteid.js/
npm install
node nodejs sample-getCertificateEstEIDAUTH.js > authcert.pem
cat authcert.pem | openssl x509  -subject -nameopt RFC2253,utf8,-esc_ctrl,-esc_msb -noout
cat authcert.pem | openssl x509 -noout -pubkey
cat authcert.pem | openssl x509 -noout -pubkey | ssh-keygen -m PKCS8 -f /dev/stdin -i|cut -f2 -d" "
