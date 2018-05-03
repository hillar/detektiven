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
bash ${SCRIPTS}/common/ensure-Virsh.bash $IMAGESDIR ${TLD} ${ORG} || die "no working virtualization"

# ensure working IDM server
[ -f ${SCRIPTS}/common/ensure-IDM.bash ] || die "missing ${SCRIPTS}/common/ensure-IDM.bash"
bash ${SCRIPTS}/common/ensure-IDM.bash || die "no working IDM on ${IPA}.${IDM}.${ORG}.${TLD}"

# ensure working syslog server
[ -f ${SCRIPTS}/common/ensure-syslog.bash ] || die "missing ${SCRIPTS}/common/ensure-syslog.bash"
bash ${SCRIPTS}/common/ensure-syslog.bash || die "no working syslog on ${LOGSERVER}"

# ensure working metrix server
[ -f ${SCRIPTS}/common/ensure-Metrix.bash ] || die "missing ${SCRIPTS}/common/ensure-Metrix.bash"
bash ${SCRIPTS}/common/ensure-Metrix.bash || die "no working metrix on ${INFLUXSERVER}"


# load vm helpers
VMHELPERS="${SCRIPTS}/common/vmHelpers.bash"
[ -f ${VMHELPERS} ] || die "missing ${VMHELPERS}"
source ${VMHELPERS}

# set hosts

sed -i '/^# BEGIN DETECTIVEN CORE HOSTS/,/^# END DETECTIVEN CORE HOSTS/ d' /etc/hosts
cat <<EOF >>/etc/hosts
# BEGIN DETECTIVEN CORE HOSTS
# created $(date) with $0
$(vm_getip ${IDMSERVER}) ${IDMSERVER}
$(vm_getip ${LOGSERVER}) ${LOGSERVER}
$(vm_getip ${INFLUXSERVER}) ${INFLUXSERVER}
# END DETECTIVEN CORE HOSTS
EOF

# prepare java dummy
[ -z ${DUMMY} ] && die "no DUMMY"
NAME="${DUMMY}-java"
if ! vm_exists ${NAME}; then
  [ -z ${SSHUSER} ] && die "no SSHUSER"
  KEYFILE="${SSHUSER}.key"
  [ -f ${KEYFILE} ] || die "no key file ${KEYFILE} for user ${SSHUSER}"
  INSTALLSCRIPT="${SCRIPTS}/common/ensure-java.bash"
  [ -f ${INSTALLSCRIPT} ] || die "missing ${INSTALLSCRIPT}"
  log "creating new ${NAME} from ${DUMMY}"
  vm_clone ${DUMMY} ${NAME} ${SSHUSER} || die "failed to clone from ${DUMMY}"
  vm_start ${NAME} > /dev/null || die "failed to start ${NAME}"
  ip=$(vm_getip ${NAME}) || die "failed to get ip for ${NAME}"
  vm_waitforssh ${NAME} ${USER}.key ${USER} > /dev/null || die "failed ssh to ${NAME}"
  scp -i ${USER}.key ${INSTALLSCRIPT} ${USER}@${ip}:
  ssh -i ${USER}.key ${USER}@${ip} "sudo bash $(basename ${INSTALLSCRIPT})"
  [ $? -ne 0 ] && die "failed install ${INSTALLSCRIPT}"
  vm_stop ${NAME}
fi

# prepare nodejs dummy
NAME="${DUMMY}-nodejs"
if ! vm_exists ${NAME}; then
  [ -z ${SSHUSER} ] && die "no SSHUSER"
  KEYFILE="${SSHUSER}.key"
  [ -f ${KEYFILE} ] || die "no key file ${KEYFILE} for user ${SSHUSER}"
  INSTALLSCRIPT="${SCRIPTS}/common/ensure-nodejs.bash"
  [ -f ${INSTALLSCRIPT} ] || die "missing ${INSTALLSCRIPT}"
  log "creating new ${NAME} from ${DUMMY}"
  vm_clone ${DUMMY} ${NAME} ${SSHUSER} || die "failed to clone from ${DUMMY}"
  vm_start ${NAME} > /dev/null || die "failed to start ${NAME}"
  ip=$(vm_getip ${NAME}) || die "failed to get ip for ${NAME}"
  vm_waitforssh ${NAME} ${USER}.key ${USER} > /dev/null || die "failed ssh to ${NAME}"
  scp -i ${USER}.key ${INSTALLSCRIPT} ${USER}@${ip}:
  ssh -i ${USER}.key ${USER}@${ip} "sudo bash $(basename ${INSTALLSCRIPT})"
  [ $? -ne 0 ] && die "failed install ${INSTALLSCRIPT}"
  vm_stop ${NAME}
fi
