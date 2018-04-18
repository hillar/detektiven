#!/usr/bin/env bash
#
# build up vm's running detektiven
#
# ! WARNING installing virsh if not installed
#
# vm's:
# 1. freeipa
# 2. metrix
# 3. ...

log() { echo "$(date) $0: $*"; }
die() { log ": $*" >&2; exit 1; }

# apt or dnf
apt --help > /dev/null 2>&1
[ $? -eq 0 ] && DANPFT='apt'
dnf --help > /dev/null 2>&1
[ $? -eq 0 ] && DANPFT='dnf'
[ -z ${DANPFT} ] && die 'no apt nor dnf'

# TODO guest os as param, options: fedora,centos und ubuntu
# for now all guest are fedora's
GUESTOS='fedora'

# TODO IDM (freeipa) as param to existing installation
# currently build one from scratch
IDM='freeipa-x'
DOM='domain'
ORG='organization'
TLD='topleveldomain'
BASE="dc=${DOM},dc=${ORG},dc=${TLD}"
DOMAIN="${DOM}.${ORG}.${TLD}"
IDMSERVER="${IDM}.${DOM}.${ORG}.${TLD}"

# current working directory
SCRIPTS="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"


# ensure we have virsh and friends
IMAGES="$(dirname ${SCRIPTS})/images" # <- change this :: if virsh is not installed, changes /var/lib/libvirt/images 
[ -f ${SCRIPTS}/common/ensure-Virsh.bash ] || die "missing ${SCRIPTS}/common/ensure-Virsh.bash"
bash ${SCRIPTS}/common/ensure-Virsh.bash $IMAGES || die "no working virtualization"

# ensure we have working IDM server
[ -f ${SCRIPTS}/common/ensure-IDM.bash ] || die "missing ${SCRIPTS}/common/ensure-IDM.bash"
bash ${SCRIPTS}/common/ensure-IDM.bash ${IDM} ${DOM} ${ORG} ${TLD} || die "no working IDM on ${IDM}.${DOM}.${ORG}.${TLD}"
