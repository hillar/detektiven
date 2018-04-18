#!/usr/bin/env bash
#
# build up vm's running detektiven
#
# !!! all params are in "./defaults", change there if needed
#
# ! WARNING installing virsh if not found
#
# vm's:
# infra
# 1. freeipa
# 2. metrix
# 3. syslog
# workers
# 1. clamav
# 2. tika
# 3. solr
# 4. ...

log() { echo "$(date) $0: $*"; }
die() { log "$*" >&2; exit 1; }

# apt or dnf
apt --help > /dev/null 2>&1
[ $? -eq 0 ] && DANPFT='apt'
dnf --help > /dev/null 2>&1
[ $? -eq 0 ] && DANPFT='dnf'
[ -z ${DANPFT} ] && die 'no apt nor dnf'

# current working directory
SCRIPTS="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

# load params
DEFAULTS="${SCRIPTS}/defaults"
[ -f ${DEFAULTS} ] || die "missing ${DEFAULTS}"
source ${DEFAULTS}

# ensure we have virsh and friends
[ -f ${SCRIPTS}/common/ensure-Virsh.bash ] || die "missing ${SCRIPTS}/common/ensure-Virsh.bash"
bash ${SCRIPTS}/common/ensure-Virsh.bash $IMAGESDIR || die "no working virtualization"

# ensure working IDM server
[ -f ${SCRIPTS}/common/ensure-IDM.bash ] || die "missing ${SCRIPTS}/common/ensure-IDM.bash"
bash ${SCRIPTS}/common/ensure-IDM.bash ${IDM} ${DOM} ${ORG} ${TLD} || die "no working IDM on ${IDM}.${DOM}.${ORG}.${TLD}"

# ensure working syslog server

# ensure working metrix server
