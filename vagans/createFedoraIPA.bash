#!/usr/bin/env bash
# build IPA on Fedora 27

log() { echo "$(date) $0: $*"; }
die() { log ": $*" >&2; exit 1; }

[ "$EUID" -ne 0 ] && die "Please run as root"

USERNAME='root'
[ -z $1 ] || USERNAME=$1
IPA='freeipa-default'
[ -z $2 ] || IPA=$2
DOMAIN='idm.domain.tld'
[ -z $3 ] || DOMAIN=$3
DUMMY='dummy-fedora'
[ -z $4 ] || DUMMY=$4
ENROLL='hostenrollllement'
[ -z $5 ] || ENROLL=$5
ADMIN='systemadministrator'
[ -z $6 ] || ADMIN=$6
[ -z $7 ] || BACKUP=$7

KEYFILE="${USERNAME}.key"

SCRIPTS="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

log "starting with ${USERNAME} ${IPA} ${DOMAIN} ${DUMMY} ${ENROLL} ${ADMIN} ${SCRIPTS}"
HELPERS="${SCRIPTS}/vmHelpers.bash"
CREATEDUMMY="${SCRIPTS}/createFedoraDummy.bash"
[ -f ${HELPERS} ] || die "missing ${HELPERS}"
source ${HELPERS}

IPA0="${IPA}.${DOMAIN}"
if ! vm_exists ${IPA0}; then
  if ! vm_exists ${DUMMY}; then
    [ -f ${CREATEDUMMY} ] || die "missing ${CREATEDUMMY}"
    log "creating very first dummy ${DUMMY} "
    bash ${CREATEDUMMY} ${USERNAME} ${DUMMY}
    virsh dumpxml ${DUMMY} > ${DUMMY}.xml
  fi
  vm_exists ${DUMMY} || die "failed to create dummy ${DUMMY}"
  log "creating IPA ${IPA0}"
  vm_clone ${DUMMY} ${IPA0} ${USERNAME}
  vm_exists ${IPA0} || die "failed to create IPA ${IPA0}"
fi

  [ -f ${IPA}.masterpwd ] || P=$(cat /dev/urandom | tr -dc 'a-zA-Z0-9' | fold -w 32 | head -n 1)
  [ -f ${IPA}.masterpwd ] || echo $P > ${IPA}.masterpwd
  [ -f ${IPA}.masterpwd ] || die 'can not find Directory Manager (existing master) password'
  P=$(cat ${IPA}.masterpwd)
  #log "$IPA0 Directory Manager password: ${P}"
  vm_start ${IPA0}
  ip=$(vm_getip ${IPA0})
  [ $? -ne 0 ] && die "failed to get ip address for vm ${IPA0}"
  vm_waitforssh ${IPA0} ${KEYFILE} root
  [ $? -ne 0 ] && die "failed to ssh into vm ${IPA0}"

  ssh -oStrictHostKeyChecking=no -i ${KEYFILE} ${USERNAME}@${ip} "echo "${ip} ${IPA0} ${IPA}" >> /etc/hosts"
  png=$(ssh -oStrictHostKeyChecking=no -i ${KEYFILE} ${USERNAME}@${ip} "ping -c1 ${IPA0}")
  IPAHELPERS="${SCRIPTS}/ipaHelpers.bash"
  [ -f $IPAHELPERS ] || die "missing $IPAHELPERS"
  source $IPAHELPERS
  if [ -z $BACKUP ]; then
    #ipainstalled=$(ssh -oStrictHostKeyChecking=no -i ${KEYFILE} ${USERNAME}@${ip} 'LC_ALL="";ipactl status')
    ipainstalled=$(ssh -oStrictHostKeyChecking=no -i ${KEYFILE} ${USERNAME}@${ip} 'netstat -ntple | grep ns-slapd  | wc -l')
    if [ ! $ipainstalled -eq 2 ]; then
      log "${IPA0} ${ip} preparing packages "
      ssh -oStrictHostKeyChecking=no -i ${KEYFILE} ${USERNAME}@${ip} 'yum -y install rng-tools; systemctl enable rngd; systemctl start rngd'
      ssh -oStrictHostKeyChecking=no -i ${KEYFILE} ${USERNAME}@${ip} 'yum -y install ipa-server ipa-server-dns'
      # !? missing yum install dbus-python
      log "installing new IPA SERVER"
      ssh -oStrictHostKeyChecking=no -i ${KEYFILE} ${USERNAME}@${ip} "echo -en 'yes\n\n\n\n${P}\n${P}\n${P}\n${P}\n\n\n\n\nyes\n' | ipa-server-install"
      # Be sure to back up the CA certificates stored in /root/cacert.p12
      # These files are required to create replicas. The password for these
      # files is the Directory Manager password
    else
      log "IPA already installed on ${IPA0}"
    fi
    # prep some defaults
    ipa_user_exists ${ip} ${KEYFILE} ${USERNAME} ${P} ${ADMIN} || ipa_preparedefaults ${ip} ${KEYFILE} ${USERNAME} ${P} ${ENROLL} ${ADMIN}
    ipa_user_exists ${ip} ${KEYFILE} ${USERNAME} ${P} ${ENROLL}
  else
    log "restoring IPA SERVER from $BACKUP"
    # https://access.redhat.com/documentation/en-us/red_hat_enterprise_linux/7-beta/html/linux_domain_identity_authentication_and_policy_guide/restore
    # https://pagure.io/freeipa/issue/7231
    # skip install if ver is > 4.5
    #ssh -oStrictHostKeyChecking=no -i ${KEYFILE} ${USERNAME}@${ip} "echo -en 'yes\n\n\n\n${P}\n${P}\n${P}\n${P}\n\n\n\n\nyes\n' | ipa-server-install"
    # still bug
    # https://pagure.io/freeipa/issue/7473
    # https://fedorapeople.org/groups/freeipa/prci/jobs/8f8a6bee-3161-11e8-a318-fa163ed2d6e2/report.html
    scp -oStrictHostKeyChecking=no -i ${KEYFILE} -r $BACKUP ${USERNAME}@${ip}:
    ssh -oStrictHostKeyChecking=no -i ${KEYFILE} ${USERNAME}@${ip} "ipa-restore --unattended --password=${P} /root/$(basename $BACKUP)"
    ssh -oStrictHostKeyChecking=no -i ${KEYFILE} ${USERNAME}@${ip} "systemctl stop sssd; find /var/lib/sss/ ! -type d | xargs rm -f"
    vm_reboot ${IPA0}
    vm_waitforssh ${IPA0}
    [ $? -ne 0 ] && waitforssh ${IPA0}
    [ $? -ne 0 ] && die "failed to ssh into vm ${IPA0}"
    ssh -oStrictHostKeyChecking=no -i ${KEYFILE} ${USERNAME}@${ip} "ipactl status"
    # Failed to start pki-tomcatd Service
    ipa_user_exists ${ip} ${KEYFILE} ${USERNAME} ${P} ${ADMIN}
    ipa_user_exists ${ip} ${KEYFILE} ${USERNAME} ${P} ${ENROLL}
  fi
log "done with ${IPA0}"
