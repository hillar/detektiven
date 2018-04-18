#!/usr/bin/env bash
# ensure IPA

log() { echo "$(date) $(basename $0): $*"; }
die() { log "$*" >&2; exit 1; }

[ "$EUID" -ne 0 ] && die "Please run as root"

SCRIPTS="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

[ -z $1 ] && die 'no IPA name'
IPA=$1
[ -z $2 ] && die "no DOMAIN for ${IPA}"
DOM=$2
[ -z $3 ] && die "no ORG for ${IPA}"
ORG=$3
[ -z $4 ] && die "no TLD for ${IPA}"
TLD=$4

BASE="dc=${DOM},dc=${ORG},dc=${TLD}"
DOMAIN="${DOM}.${ORG}.${TLD}"

USER='root'
DUMMY='dummy-fedora'
ENROLL='hostenroll'
ADMIN='sysadm'
READONLY='onlyread'
KEYFILE="${USER}.key"
MASTERPASSWORDFILE="${IPA}.masterpwd"

VMHELPERS="${SCRIPTS}/vmHelpers.bash"
[ -f ${VMHELPERS} ] || die "missing ${VMHELPERS}"
source ${VMHELPERS}
IPAHELPERS="${SCRIPTS}/ipaHelpers.bash"
[ -f $IPAHELPERS ] || die "missing $IPAHELPERS"
source $IPAHELPERS
IPA0="${IPA}.${DOMAIN}"
if ! vm_exists ${IPA0} ; then
  [ -f ${SCRIPTS}/../fedora/createFedoraIPA.bash ] || die "missing ${SCRIPTS}/../fedora/createFedoraIPA.bash"
  bash ${SCRIPTS}/../fedora/createFedoraIPA.bash ${USER} ${IPA} ${DOMAIN} ${DUMMY} ${ENROLL} ${ADMIN}
  vm_exists ${IPA0}  || die "failed to create ${IPA}"
fi
[ -f ${KEYFILE} ] || die "no key file ${KEYFILE} for user ${USER}"
[ -f ${MASTERPASSWORDFILE} ] || die "no master password for ${IPA0}"
P=$(cat ${MASTERPASSWORDFILE})
vm_running ${IPA0} || vm_start ${IPA0}
ip=$(vm_getip ${IPA0})
[ -z ${ip} ] && die "no ip for ${IPA0}"
vm_waitforssh ${IPA0} ${KEYFILE} ${USER} || die "failed to ssh into vm ${IPA0}"
ok=$(ssh -i ${KEYFILE} ${USER}@${ip} "LC_ALL="";echo "${P}" | kinit admin > /dev/null; echo \$?")
[ ${ok} -ne 0 ] && die "incorrect master password ${IPA0}"
ipa_user_exists ${ip} ${KEYFILE} ${USER} ${P} ${ADMIN}
ipa_user_exists ${ip} ${KEYFILE} ${USER} ${P} ${ENROLL}
#ipa_user_exists ${ip} ${KEYFILE} ${USER} ${P} ${READONLY}
ldapsearch -x -D "uid=admin,cn=users,cn=accounts,${BASE}" -w ${P} -h ${ip} -b "cn=accounts,${BASE}" -s sub 'uid=admin' > /dev/null
[ $? -ne 0 ] && die "ldap error ${IPA0}"
ldapsearch -x -D "uid=admin,cn=users,cn=accounts,${BASE}" -w ${P} -h ${ip} -b "cn=accounts,${BASE}" -s sub 'uid=hostenroll' > /dev/null
[ $? -ne 0 ] && die "ldap error ${IPA0}"
log "${IPA0} seems ok"
