#!/usr/bin/env bash
# ensure metrix (influxdb)
# loads params from ../defaults
# if metrix not exists, create on from scratch
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
[ -z $1 ] || INFLUXSERVER=$1
[ -z ${INFLUXSERVER} ] && die 'no INFLUXSERVER name'


# ping existing metrix, if no pong, look for vm
ping -c1 ${INFLUXSERVER} > /dev/null 2>&1
if [ $? -eq 0 ]; then
  nc -h > /dev/null 2>&1 || die "no nc, please install!"
  nc -vz -u ${INFLUXSERVER} 8089 > /dev/null 2>&1
  if [ $? -eq 0 ]; then
    log "metrix works ${INFLUXSERVER} 8089"
    exit 0
  else
    log "metrix ${INFLUXSERVER} exists, but not listening on 8089"
  fi
fi
if ! vm_exists ${INFLUXSERVER} ; then
  [ -f ${SCRIPTS}/../fedora/createFedoraMetrix.bash ] || die "missing ${SCRIPTS}/../fedora/createFedoraMetrix.bash"
  bash ${SCRIPTS}/../fedora/createFedoraMetrix.bash ${INFLUXSERVER}
  vm_exists ${INFLUXSERVER}  || die "failed to create metrix server ${INFLUXSERVER}"
fi
# start vm
vm_start ${INFLUXSERVER} > /dev/null 2>&1 || die "failed to start ${INFLUXSERVER}"
vm_getip ${INFLUXSERVER} > /dev/null 2>&1 || die "failed to get ip ${INFLUXSERVER}"
[ -z ${SSHUSER} ] && die 'no SSHUSER'
KEYFILE="${SSHUSER}.key"
[ -f ${KEYFILE} ] || die "no key file ${KEYFILE} for user ${SSHUSER}"
vm_waitforssh ${INFLUXSERVER} ${KEYFILE} ${SSHUSER} > /dev/null 2>&1 || die "failed to ssh ${INFLUXSERVER}"

# ping new metrix port 8089, if no pong, die
nc -h > /dev/null 2>&1 || die "no nc, please install!"
nc -vz -u ${INFLUXSERVER} 8089 > /dev/null 2>&1
if [ $? -eq 0 ]; then
  log "metrix works ${INFLUXSERVER} 8089"
  exit 0
else
  die "metrix ${INFLUXSERVER} exists, but not listening on 8089"
fi
