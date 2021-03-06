#!/bin/bash

# prepare new xenial


log() { echo "$(date) $0: $*"; }
die() { log ": $*" >&2; exit 1; }
[ "$EUID" -ne 0 ] && die "Please run as root"
SCRIPTS="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
VMHELPERS="${SCRIPTS}/vmHelpers.bash"
[ -f ${VMHELPERS} ] || die "missing ${VMHELPERS}"
source ${VMHELPERS}

[ -z $1 ] && die 'no name'
[ -z $1 ] || NAME=$1
PARENT='dummy-xenial-2'
[ -z $2 ] || PARENT=$2
USER='dummy'
[ -z $3 ] || USER=$3
[ -f "${USER}.key" ] || die "no key for ${USER}"
[ -f "${USER}.key.pub" ] || die "no pub key for ${USER}"

IPA='freeipa0'
DOMAIN='idm.domain.tld'
IPA0="${IPA}.${DOMAIN}"
IPAIP=$(vm_getip ${IPA0}) || die "no ip ${IPA0}"
ENROLL='hostenroll'
ADMIN='sysadm'

[ -f ${ENROLL}.passwd ] || die "no passwd for ${ENROLL}"
ENROLLPASSWORD=$(cat ${ENROLL}.passwd)
[ -f ${ADMIN}.passwd ] || die "no passwd for ${ADMIN}"
ADMINPASSWORD=$(cat ${ADMIN}.passwd)
if ! vm_exists ${NAME}; then
  log "creating new ${NAME} from ${PARENT}"
  vm_clone ${PARENT} ${NAME} ${USER} || die "failed to clone from ${PARENT}"
fi
vm_start ${NAME} > /dev/null || die "failed to start ${NAME}"
ip=$(vm_getip ${NAME}) || die "failed to get ip for ${NAME}"
vm_waitforssh ${NAME} ${USER}.key ${USER} > /dev/null || die "failed ssh to ${NAME}"
cat > prepare-$IPA-client.bash <<EOF
LC_ALL="";
echo "${IPAIP} ${IPA0}" >> /etc/hosts
hn=\$(hostname -f)
echo "\$hn > /etc/hostname"
hostname \$hn
ping -c1 ${IPA0} > /dev/null
if [ \$? -eq 0 ]; then
  export DEBIAN_FRONTEND=noninteractive;
  apt-get -y install freeipa-client;
  ipa-client-install -p ${ENROLL} -w ${ENROLLPASSWORD} --domain ${DOMAIN} --server ${IPA0} --fixed-primary --no-ntp --force --unattended --force-join
  echo "${ADMINPASSWORD}" | kinit ${ADMIN}
  if [ $? -eq 0 ]; then
      klist
  else
    echo "ERROR, can not log in as ${ADMIN}"
    exit 1
  fi
else
  echo "ERROR, can not find ${IPA0}"
  exit 1
fi
EOF
scp -i ${USER}.key prepare-$IPA-client.bash ${USER}@${ip}:
ssh -i ${USER}.key ${USER}@${ip} "sudo bash -x prepare-$IPA-client.bash"
