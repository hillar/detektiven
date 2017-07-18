cd /var/local/
[ -d esteid ] || mkdir esteid
cd esteid


DOMAIN="webeid.com"

EN=$( echo $1 | egrep  -o "[0-9]{11}")

if [ !  -z $EN ]
then
  mkdir $EN
  cd  $EN
  rm -rf *
  ldapsearch -x -h ldap.sk.ee -b c=EE "(serialNumber=$EN)" -o ldif-wrap=no -LLL > orig.txt
  awk -v RS= '{print > ("cert-" NR ".txt")}' orig.txt
  ls cert-*.txt | while read certfile;
  do
    echo $certfile
    c=$(head -4 $certfile  | tail -1 | cut -f2 -d" ")
    if [ "$(head -1  $certfile | cut -f2 -d,)"  != "ou=authentication" ];
    then
      SUBJ=$(echo "$c" | base64 -d | openssl x509 -inform DER -noout -subject -nameopt RFC2253,utf8,-esc_ctrl,-esc_msb)
      echo $SUBJ | cut -d, -f3| cut -d= -f2 >> SN.txt
      echo $SUBJ | cut -d, -f2| cut -d= -f2 >> GN.txt
      echo $SUBJ | cut -d, -f1| cut -d= -f3 >> SSN.txt
      pem=$(echo "$c" | base64 -d | openssl x509 -inform DER -noout -pubkey)
      sshkey=$(echo "$pem" | ssh-keygen -m PKCS8 -f /dev/stdin -i|cut -f2 -d" ")
      echo "$sshkey" >> sshkeys.txt
    else
      echo "$c" | base64 -d | openssl x509 -inform DER -noout -email >> emails.txt
      echo "$c" >> certs.txt
    fi
  done
  [ "$(cat SSN.txt | sort | uniq | wc -l)" -eq 1 ] || exit
  SSN=$(cat SSN.txt | sort | uniq)
  [ "$SSN" -eq "$EN" ] || exit
  [ "$(cat emails.txt | sort | uniq | wc -l)" -eq 1 ] || exit
  [ "$(cat SN.txt | sort | uniq | wc -l)" -eq 1 ] || exit
  [ "$(cat GN.txt | sort | uniq | wc -l)" -eq 1 ] || exit
  EMAIL=$(cat emails.txt | sort | uniq)
  SN=$(cat SN.txt | sort | uniq)
  GN=$(cat GN.txt | sort | uniq)
  UNAME=$(echo $EMAIL | cut -f1 -d"@")
  echo "$SSN  $UNAME $GN $SN $EMAIL"
  # Add a user with multiple SSH public keys:
  # $ ipa user-add user --sshpubkey='ssh-rsa AAAA…'
  # --sshpubkey='ssh-dss AAAA…'
  # https://www.freeipa.org/images/d/d2/Freeipa30_SSH_Public_Keys.pdf
  sshkeys=""
  while read key;
  do
    sshkeys="$sshkeys --sshpubkey=\"$key\" "
  done < <(cat sshkeys.txt)
  certs="";
  while read crt;
  do
    certs="$certs --certificate=\"$crt\" "
  done < <(cat certs.txt)
  cmd_adduser="ipa user-add $UNAME --first=$GN --last=$SN --employeenumber=$SSN --email=$EMAIL $sshkeys $certs"
  $cmd_adduser

fi
