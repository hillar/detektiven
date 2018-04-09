#!/usr/bin/env bash
# ensure IPA

log() { echo "$(date) $0: $*"; }
die() { log ": $*" >&2; exit 1; }
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
KEYFILE="${USER}.key"
MASTERPASSWORDFILE="${IPA}.masterpwd"
DUMMY='dummy-fedora'

VMHELPERS="${SCRIPTS}/virtHelpers.bash"
[ -f ${VMHELPERS} ] || die "missing ${VMHELPERS}"
source ${VMHELPERS}

if [ ! $(vm_exists ${IPA}) = '0' ]; then
  [ -f ${SCRIPTS}/createFedoraIPA.bash ] || die "missing ${SCRIPTS}/createCentosIPA.bash"
  bash -x ${SCRIPTS}/createFedoraIPA.bash ${USER} ${IPA} ${DOMAIN} ${DUMMY}
  [ ! $(vm_exists ${IPA}) = '0' ] && die "failed to create ${IPA}"
fi
[ -f ${KEYFILE} ] || die "no key file ${KEYFILE} for user ${USER}"
[ -f ${MASTERPASSWORDFILE} ] || die "no master password for ${IPA}"
P=$(cat ${MASTERPASSWORDFILE})
start_vm ${IPA}
ip=$(getip_vm ${IPA})
[ -z ${ip} ] && die "no ip for ${IPA}"
waitforssh ${IPA} ${KEYFILE} ${USER}
[ $? -ne 0 ] && die "failed to ssh into vm ${IPA}"
ok=$(ssh -i ${KEYFILE} ${USER}@${ip} "echo "${P}" | kinit admin > /dev/null; echo \$?")
[ ${ok} -ne 0 ] && die "incorrect master password ${IPA}"
ok=$(ssh -i ${KEYFILE} ${USER}@${ip} "echo "${P}" | kinit admin > /dev/null; ipa user-find admin > /dev/null; echo \$?"
)
[ ${ok} -ne 0 ] && die "ipa error ${IPA}"
ldapsearch -x -D "uid=admin,cn=users,cn=accounts,${BASE}" -w ${P} -h ${ip} -b "cn=accounts,${BASE}" -s sub 'uid=admin' > /dev/null
[ $? -ne 0 ] && die "ldap error ${IPA}"
log "${IPA} seems ok"

IPAHELPERS="${SCRIPTS}/ipaHelpers.bash"
[ -f ${IPAHELPERS} ] || die "missing ${IPAHELPERS}"
source ${IPAHELPERS}
hostenroll ${ip} ${KEYFILE} ${USER} ${P}
