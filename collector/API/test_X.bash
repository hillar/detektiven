
# for i in $(seq 1 60); do echo "$i";bash test_X.bash >> /tmp/t60;echo "*****"; sleep 1; done

echo "new key pair..."
openssl genrsa 1024 > private.pem
openssl rsa -pubout -in private.pem > public.pem
echo "test 1: js sign"
node sign.js -n nn -m ll@kk -k private.pem > token_js;
node verify.js -t token_js -p public.pem;
bash verify.bash token_js public.pem
echo "" | pyjwt --key "$(cat public.pem)" decode "$(cat token_js)"
echo""
echo "test 2: bash sign"
bash sign.bash bb kk@ll 100 private.pem > token_sh
bash verify.bash token_sh public.pem
node verify.js -t token_sh -p public.pem;
echo "" | pyjwt --key "$(cat public.pem)" decode "$(cat token_sh)"
echo ""
echo "test 3: pyjwt sign"
echo "" | pyjwt --alg RS256 --key "$(cat private.pem)" encode  nonce=pp email=kk@ll  exp=+100 > token_py
echo "" | pyjwt --key "$(cat public.pem)" decode "$(cat token_py)"
bash verify.bash token_py public.pem
node verify.js -t token_py -p public.pem;
