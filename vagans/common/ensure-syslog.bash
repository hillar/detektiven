#!/usr/bin/env bash
# ensure syslog (rsyslog)
# loads params from ../defaults
# if syslog not exists, create on from scratch
#
# ! WARNING depends on nc

log() { echo "$(date) $(basename $0): $*"; }
die() { log "$*" >&2; exit 1; }

[ "$EUID" -ne 0 ] && die "Please run as root"

SCRIPTS="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
VMHELPERS="${SCRIPTS}/vmHelpers.bash"
[ -f ${VMHELPERS} ] || die "missing ${VMHELPERS}"
source ${VMHELPERS}
DEFAULTS="${SCRIPTS}/../defaults"
[ -f ${DEFAULTS} ] || die "missing defaults ${DEFAULTS}"
source ${DEFAULTS}
[ -z $1 ] || LOGSERVER=$1
[ -z ${LOGSERVER} ] && die 'no LOGSERVER name'


# ping existing syslog, if no pong, look for vm
ping -c1 ${LOGSERVER} > /dev/null 2>&1
if [ $? -eq 0 ]; then
  nc -h > /dev/null 2>&1 || die "no nc, please install!"
  nc -vz -u ${LOGSERVER} 514 > /dev/null 2>&1
  if [ $? -eq 0 ]; then
    log "syslog works ${LOGSERVER} 514"
    exit 0
  else
    log "syslog ${LOGSERVER} exists, but not listening on 514"
  fi
fi
if ! vm_exists ${LOGSERVER} ; then
  [ -f ${SCRIPTS}/../fedora/createFedoraSyslog.bash ] || die "missing ${SCRIPTS}/../fedora/createFedoraSyslog.bash"
  bash ${SCRIPTS}/../fedora/createFedoraSyslog.bash ${LOGSERVER}
  vm_exists ${LOGSERVER}  || die "failed to create syslog server ${LOGSERVER}"
fi
# start vm
vm_start ${LOGSERVER} > /dev/null 2>&1 || die "failed to start ${LOGSERVER}"
ip=$(vm_getip ${LOGSERVER}) || die "failed to get ip ${LOGSERVER}"
[ -z ${SSHUSER} ] && die 'no SSHUSER'
KEYFILE="${SSHUSER}.key"
[ -f ${KEYFILE} ] || die "no key file ${KEYFILE} for user ${SSHUSER}"
vm_waitforssh ${LOGSERVER} ${KEYFILE} ${SSHUSER} > /dev/null 2>&1 || die "failed to ssh ${LOGSERVER}"

# ping new syslog port 8089, if no pong, die
nc -h > /dev/null 2>&1 || die "no nc, please install!"
nc -vz -u ${ip} 514 > /dev/null 2>&1
if [ $? -eq 0 ]; then
  log "syslog vm works ${LOGSERVER} 514"
  exit 0
else
  die "syslog vm ${LOGSERVER} exists, but not listening on 514"
fi
