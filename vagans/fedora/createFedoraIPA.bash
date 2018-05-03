#!/usr/bin/env bash
# build IPA on Fedora 27
# params TLD ORG DOMAIN IPA (BACKUP MASTERPWD)
# if BACKUP given, will restore instead of install

log() { echo "$(date) $(basename $0): $*"; }
die() { log "$*" >&2; exit 1; }

[ "$EUID" -ne 0 ] && die "Please run as root"
SCRIPTS="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"


[ -z $1 ] && die 'no TLD'
TLD=$1
[ -z $2 ] && die 'no ORG'
ORG=$2
[ -z $3 ] && die 'no DOMAIN'
DOM=$3
[ -z $4 ] && die 'no IPA server name'
IPA=$4
[ -z $5 ] || BACKUP=$5
[ -z $6 ] || MASTERPWD=$6

DEFAULTS="${SCRIPTS}/../defaults"
[ -f ${DEFAULTS} ] && source ${DEFAULTS}
[ -f ${DEFAULTS} ] && log "loading params from  ${DEFAULTS}"
[ -f ${DEFAULTS} ] || log "using hardcoded prarams, as missing defaults ${DEFAULTS}"
[ -z ${DUMMY} ] && DUMMY='fedora-dummy'
[ -z ${SSHUSER} ] && SSHUSER='root'
[ -z ${ENROLL} ] && ENROLL='hostenroll'
[ -z ${ADMIN} ] && ADMIN='sysadm'
[ -z ${READONLY} ] && READONLY='onlyread'

KEYFILE="${SSHUSER}.key"

log "starting with ${TLD} ${ORG} ${DOM} ${IPA}"
HELPERS="${SCRIPTS}/../common/vmHelpers.bash"
CREATEDUMMY="${SCRIPTS}/createFedoraDummy.bash"
[ -f ${HELPERS} ] || die "missing ${HELPERS}"
source ${HELPERS}

IPA0="${IPA}.${DOM}.${ORG}.${TLD}"
if ! vm_exists ${IPA0}; then
  if ! vm_exists ${DUMMY}; then
    log "no parent ${DUMMY}, going to create new"
    [ -f ${CREATEDUMMY} ] || die "missing ${CREATEDUMMY}"
    bash ${CREATEDUMMY} ${SSHUSER} ${DUMMY}
  fi
  vm_exists ${DUMMY} || die "no new parent ${DUMMY}"
  KEYFILE="${SSHUSER}.key"
  [ -f ${KEYFILE} ] || die "no key file ${KEYFILE} for user ${SSHUSER}"
  log "creating IPA ${IPA0}"
  vm_clone ${DUMMY} ${IPA0} ${SSHUSER}
  vm_exists ${IPA0} || die "failed to create IPA ${IPA0}"
fi
# if not masterpwd given as param, look for default, if not create one
if [ -z $MASTERPWD ]; then
  [ -f ${IPA}.masterpwd ] || P=$(cat /dev/urandom | tr -dc 'a-zA-Z0-9' | fold -w 32 | head -n 1)
  [ -f ${IPA}.masterpwd ] || echo $P > ${IPA}.masterpwd
  [ -f ${IPA}.masterpwd ] || die 'can not find Directory Manager (existing master) password'
  P=$(cat ${IPA}.masterpwd)
else
  # is it file or pass
  if [ -f $MASTERPWD ]; then
    P=$(cat $MASTERPWD)
  else
    P=$MASTERPWD
  fi
fi
vm_start ${IPA0}
ip=$(vm_getip ${IPA0})
[ $? -ne 0 ] && die "failed to get ip address for vm ${IPA0}"
vm_waitforssh ${IPA0} ${KEYFILE} root
[ $? -ne 0 ] && die "failed to ssh into vm ${IPA0}"

ssh -oStrictHostKeyChecking=no -i ${KEYFILE} ${SSHUSER}@${ip} "echo "${ip} ${IPA0} ${IPA}" >> /etc/hosts"
png=$(ssh -oStrictHostKeyChecking=no -i ${KEYFILE} ${SSHUSER}@${ip} "ping -c1 ${IPA0}")
IPAHELPERS="${SCRIPTS}/../common/ipaHelpers.bash"
[ -f $IPAHELPERS ] || die "missing $IPAHELPERS"
source $IPAHELPERS
if [ -z $BACKUP ]; then
  #ipainstalled=$(ssh -oStrictHostKeyChecking=no -i ${KEYFILE} ${SSHUSER}@${ip} 'LC_ALL="";ipactl status')
  ipainstalled=$(ssh -oStrictHostKeyChecking=no -i ${KEYFILE} ${SSHUSER}@${ip} 'netstat -ntple | grep ns-slapd  | wc -l')
  if [ ! $ipainstalled -eq 2 ]; then
    log "${IPA0} ${ip} preparing packages "
    ssh -oStrictHostKeyChecking=no -i ${KEYFILE} ${SSHUSER}@${ip} 'yum -y install rng-tools; systemctl enable rngd; systemctl start rngd'
    ssh -oStrictHostKeyChecking=no -i ${KEYFILE} ${SSHUSER}@${ip} 'yum -y install ipa-server ipa-server-dns'
    # !? missing yum install dbus-python
    log "installing new IPA SERVER"
    ssh -oStrictHostKeyChecking=no -i ${KEYFILE} ${SSHUSER}@${ip} "echo -en 'yes\n\n\n\n${P}\n${P}\n${P}\n${P}\n\n\n\n\nyes\n' | ipa-server-install"
    # Be sure to back up the CA certificates stored in /root/cacert.p12
    # These files are required to create replicas. The password for these
    # files is the Directory Manager password
  else
    log "IPA already installed on ${IPA0}"
  fi
  # prep some defaults
  ipa_user_exists ${ip} ${KEYFILE} ${SSHUSER} ${P} ${ADMIN} || ipa_preparedefaults ${ip} ${KEYFILE} ${SSHUSER} ${P} ${ADMIN} ${ENROLL} ${READONLY}
  ipa_user_exists ${ip} ${KEYFILE} ${SSHUSER} ${P} ${ENROLL}
  ipa_user_exists ${ip} ${KEYFILE} ${SSHUSER} ${P} ${READONLY}
else
  log "restoring IPA SERVER from $BACKUP"
  # https://access.redhat.com/documentation/en-us/red_hat_enterprise_linux/7-beta/html/linux_domain_identity_authentication_and_policy_guide/restore
  # https://pagure.io/freeipa/issue/7231
  # skip install if ver is > 4.5
  #ssh -oStrictHostKeyChecking=no -i ${KEYFILE} ${SSHUSER}@${ip} "echo -en 'yes\n\n\n\n${P}\n${P}\n${P}\n${P}\n\n\n\n\nyes\n' | ipa-server-install"
  # still bug
  # https://pagure.io/freeipa/issue/7473
  # https://fedorapeople.org/groups/freeipa/prci/jobs/8f8a6bee-3161-11e8-a318-fa163ed2d6e2/report.html
  scp -oStrictHostKeyChecking=no -i ${KEYFILE} -r $BACKUP ${SSHUSER}@${ip}:
  ssh -oStrictHostKeyChecking=no -i ${KEYFILE} ${SSHUSER}@${ip} "ipa-restore --unattended --password=${P} /root/$(basename $BACKUP)"
  ssh -oStrictHostKeyChecking=no -i ${KEYFILE} ${SSHUSER}@${ip} "systemctl stop sssd; find /var/lib/sss/ ! -type d | xargs rm -f"
  vm_reboot ${IPA0}
  vm_waitforssh ${IPA0}
  [ $? -ne 0 ] && waitforssh ${IPA0}
  [ $? -ne 0 ] && die "failed to ssh into vm ${IPA0}"
  ssh -oStrictHostKeyChecking=no -i ${KEYFILE} ${SSHUSER}@${ip} "ipactl status"
  # Failed to start pki-tomcatd Service
  ipa_user_exists ${ip} ${KEYFILE} ${SSHUSER} ${P} ${ADMIN}
  ipa_user_exists ${ip} ${KEYFILE} ${SSHUSER} ${P} ${ENROLL}
fi
log "done with ${IPA0}"
