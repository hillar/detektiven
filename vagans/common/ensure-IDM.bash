#!/usr/bin/env bash
# ensure IPA
# loads params from ../defaults
# if IPA not exists, create on from scratch
# only Fedora will be built (because of)

log() { echo "$(date) $(basename $0): $*"; }
die() { log "$*" >&2; exit 1; }

[ "$EUID" -ne 0 ] && die "Please run as root"

SCRIPTS="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
VMHELPERS="${SCRIPTS}/vmHelpers.bash"
[ -f ${VMHELPERS} ] || die "missing ${VMHELPERS}"
source ${VMHELPERS}
IPAHELPERS="${SCRIPTS}/ipaHelpers.bash"
[ -f $IPAHELPERS ] || die "missing $IPAHELPERS"
source $IPAHELPERS
DEFAULTS="${SCRIPTS}/../defaults"
[ -f ${DEFAULTS} ] || die "missing defaults ${DEFAULTS}"
source ${DEFAULTS}

[ -z ${IPA} ] && die 'no IPA name'
MASTERPASSWORDFILE="${IPA}.masterpwd"
[ -z ${IDM} ] && die "no DOMAIN "
[ -z ${ORG} ] && die "no ORG "
[ -z ${TLD} ] && die "no TLD "
BASE="dc=${IDM},dc=${ORG},dc=${TLD}"
IDMDOMAIN="${IDM}.${ORG}.${TLD}"
[ -z ${SSHUSER} ] && die 'no SSHUSER'
KEYFILE="${SSHUSER}.key"
[ -z ${ENROLL} ] && die 'no ENROLL'
[ -f ${ENROLL}.passwd ] || die "no npassword for ${ENROLL}"
[ -z ${ADMIN} ] && die 'no ADMIN'
[ -f ${ADMIN}.passwd ] || die "no npassword for ${ADMIN}"
[ -z ${READONLY} ] && die 'no READONLY'

# good to go..

IPA0="${IPA}.${IDMDOMAIN}"
LDAPSERVER="${IPA0}"
# ping existing ipa, if no pong, look for vm
ping -c1 ${IPA0} > /dev/null 2>&1
if [ $? -ne 0 ]; then
  if ! vm_exists ${IPA0} ; then
    [ -f ${SCRIPTS}/../fedora/createFedoraIPA.bash ] || die "missing ${SCRIPTS}/../fedora/createFedoraIPA.bash"
    bash ${SCRIPTS}/../fedora/createFedoraIPA.bash ${TLD} ${ORG} ${IDM} ${IPA}
    vm_exists ${IPA0}  || die "failed to create ${IPA}"
  fi
  [ -f ${KEYFILE} ] || die "no key file ${KEYFILE} for user ${SSHUSER}"
  [ -f ${MASTERPASSWORDFILE} ] || die "no master password for ${IPA0}"
  P=$(cat ${MASTERPASSWORDFILE})
  vm_running ${IPA0} || vm_start ${IPA0}
  ip=$(vm_getip ${IPA0})
  [ -z ${ip} ] && die "no ip for ${IPA0}"
  LDAPSERVER=${ip}
  vm_waitforssh ${IPA0} ${KEYFILE} ${SSHUSER} || die "failed to ssh into vm ${IPA0}"
  ok=$(ssh -i ${KEYFILE} ${SSHUSER}@${ip} "whoami > /dev/null; echo \$?")
  [ ${ok} -ne 0 ] && die "incorrect ssh user ${IPA0}"
  [ -f ${MASTERPASSWORDFILE} ] || die "no master password for ${IPA0}"
  P=$(cat ${MASTERPASSWORDFILE})
  ok=$(ssh -i ${KEYFILE} ${SSHUSER}@${ip} "LC_ALL="";echo "${P}" | kinit admin > /dev/null; echo \$?")
  [ ${ok} -ne 0 ] && die "incorrect master password ${IPA0}"
  ipa_user_exists ${ip} ${KEYFILE} ${SSHUSER} ${P} ${ADMIN}
  ipa_user_exists ${ip} ${KEYFILE} ${SSHUSER} ${P} ${ENROLL}
  #ipa_user_exists ${ip} ${KEYFILE} ${SSHUSER} ${P} ${READONLY}
fi
#can enroll account to bind
ldapsearch -x -D "uid=${ENROLL},cn=users,cn=accounts,${BASE}" -w $(cat ${ENROLL}.passwd) -h ${LDAPSERVER} -b "cn=accounts,${BASE}" -s sub "uid=${ENROLL}" > /dev/null
[ $? -ne 0 ] && die "ldap error ${LDAPSERVER}, cant find ${ENROLL}"
ldapsearch -x -D "uid=${ADMIN},cn=users,cn=accounts,${BASE}" -w $(cat ${ADMIN}.passwd) -h ${LDAPSERVER} -b "cn=accounts,${BASE}" -s sub "uid=${ADMIN}" > /dev/null
[ $? -ne 0 ] && die "ldap error ${LDAPSERVER}, cant find ${ADMIN}"
r=$(ldapsearch -x -D "uid=${ADMIN},cn=users,cn=accounts,${BASE}" -w $(cat ${ADMIN}.passwd) -h ${LDAPSERVER} -b "cn=accounts,${BASE}" -s sub "uid=${READONLY}" | grep numEntries|wc -l)
[ $r -eq 0 ] && die "ldap error ${LDAPSERVER}, cant find ${READONLY}"
r=$(ldapsearch -x -D "uid=${READONLY},cn=users,cn=accounts,${BASE}" -w $(cat ${READONLY}.passwd) -h ${LDAPSERVER} -b "cn=accounts,${BASE}" -s sub "uid=${READONLY}" | grep numEntries|wc -l)
[ $r -eq 0 ] && die "ldap error ${LDAPSERVER}, cant bind as ${READONLY}"
log "${IPA0} seems ok"
