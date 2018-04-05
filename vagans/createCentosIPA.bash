#!/usr/bin/env bash
# build IPA on Centos 7

log() { echo "$(date) $0: $*"; }
die() { log ": $*" >&2; exit 1; }

[ "$EUID" -ne 0 ] && die "Please run as root"

SCRIPTS="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
[ -z $1 ] || SCRIPTS=$1
IPA='freeipa'
[ -z $2 ] || IPA=$2
DOMAIN='domain.tld'
[ -z $3 ] || DOMAIN=$3
DUMMY='dummy-centos'
[ -z $4 ] || DUMMY=$4
[ -z $5 ] || BACKUP=$5

HELPERS="${SCRIPTS}/virtHelpers.bash"
CREATEDUMMY="${SCRIPTS}/createCentosDummy.bash"
[ -f ${HELPERS} ] || die "missing ${HELPERS}"
source ${HELPERS}

if [ ! $(vm_exists ${DUMMY}) = '0' ]; then
  [ -f ${CREATEDUMMY} ] || die "missing ${CREATEDUMMY}"
  log "creating very first CENTOS dummy"
  bash ${CREATEDUMMY} ${USERNAME} ${HELPERS}
  virsh dumpxml ${DUMMY} > ${DUMMY}.xml
fi
[ ! $(vm_exists ${DUMMY}) = '0' ] && die "can not create ${DUMMY}"
stop_vm ${DUMMY}



IPA0="${IPA}"
if [ ! $(vm_exists ${IPA0}) = '0' ]; then
  log "creating IPA MASTER ${IPA0}"
  virt-clone -q -o ${DUMMY} -n ${IPA0} --auto-clone
fi
  [ ! $(vm_exists ${IPA0}) = '0' ] && die "can not create IPA MASTER $IPA0"
  [ -f ${IPA}.masterpwd ] || P=$(cat /dev/urandom | tr -dc 'a-zA-Z0-9' | fold -w 32 | head -n 1)
  [ -f ${IPA}.masterpwd ] || echo $P > ${IPA}.masterpwd
  [ -f ${IPA}.masterpwd ] || die 'can not find Directory Manager (existing master) password'
  P=$(cat ${IPA}.masterpwd)
  #log "$IPA0 Directory Manager password: ${P}"
  start_vm ${IPA0}
  ip=$(getip_vm ${IPA0})
  [ $? -ne 0 ] && die "failed to get ip address for vm ${IPA0}"
  log "${IPA0} ${ip} preparing packages "
  ssh-keygen -f "/root/.ssh/known_hosts" -R ${ip} > /dev/null
  ssh -oStrictHostKeyChecking=no -i dummy.key root@${ip} 'whoami' > /dev/null
  ssh -oStrictHostKeyChecking=no -i dummy.key root@${ip} "echo "${IPA0}.${DOMAIN}" > /etc/hostname; hostname "${IPA0}.${DOMAIN}""
  ssh -oStrictHostKeyChecking=no -i dummy.key root@${ip} "echo "${ip} ${IPA0}.${DOMAIN} ${IPA0}" >> /etc/hosts"
  ssh -oStrictHostKeyChecking=no -i dummy.key root@${ip} "ping -c1 ${IPA0}.${DOMAIN}"
  ssh -oStrictHostKeyChecking=no -i dummy.key root@${ip} 'yum -y install rng-tools; systemctl enable rngd; systemctl start rngd'
  ssh -oStrictHostKeyChecking=no -i dummy.key root@${ip} 'yum -y install ipa-server ipa-server-dns'
  if [ -z $BACKUP ]; then
    log "installing new IPA SERVER"
    ssh -oStrictHostKeyChecking=no -i dummy.key root@${ip} "echo -en 'yes\n\n\n\n${P}\n${P}\n${P}\n${P}\n\n\n\n\nyes\n' | ipa-server-install"
    # prep some defaults
  else
    log "restoring IPA SERVER from $BACKUP"
    # https://pagure.io/freeipa/issue/7231
    # skip install if ver is > 4.5
    ssh -oStrictHostKeyChecking=no -i dummy.key root@${ip} "echo -en 'yes\n\n\n\n${P}\n${P}\n${P}\n${P}\n\n\n\n\nyes\n' | ipa-server-install"
    scp -oStrictHostKeyChecking=no -i dummy.key -r $BACKUP root@${ip}:
    ssh -oStrictHostKeyChecking=no -i dummy.key root@${ip} "echo -en "${P}\nyes\n"| ipa-restore /root/$BACKUP"
  fi

ip=$(getip_vm ${IPA0})
curl -s $ip | wc -l
ssh -oStrictHostKeyChecking=no -i dummy.key root@${ip} "curl -s -k https://${IPA0}.${DOMAIN}/ipa/ui/ | wc -l"
#TODO check ldap
