#!/usr/bin/env bash
# build metrix server on Fedora 27
# params NAME
# installing influxdb + chronograf + kapacitor
# listening for telegraf's on udp port 8089

log() { echo "$(date) $(basename $0): $*"; }
die() { log "$*" >&2; exit 1; }

[ "$EUID" -ne 0 ] && die "Please run as root"
SCRIPTS="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
HELPERS="${SCRIPTS}/../common/vmHelpers.bash"
[ -f ${HELPERS} ] || die "missing ${HELPERS}"
source ${HELPERS}

[ -z $1 ] && die 'no name'
NAME=$1
vm_exists ${NAME} && die "vm exists ${NAME}"

DEFAULTS="${SCRIPTS}/../defaults"
[ -f ${DEFAULTS} ] && source ${DEFAULTS}
[ -f ${DEFAULTS} ] && log "loading params from  ${DEFAULTS}"
[ -f ${DEFAULTS} ] || log "using hardcoded params, as missing defaults ${DEFAULTS}"
[ -z ${SSHUSER} ] && SSHUSER='root'
KEYFILE="${SSHUSER}.key"
[ -f ${KEYFILE} ] || die "no key file ${KEYFILE} for user ${SSHUSER}"
[ -z ${DUMMY} ] && DUMMY='fedora-dummy'
[ -z ${IFLUXDBVERSION} ] && IFLUXDBVERSION='1.5.2'
[ -z ${CHRONOGRAFVERSION} ] && CHRONOGRAFVERSION='1.4.4.1'
[ -z ${KAPACITORVERSION} ] && KAPACITORVERSION='1.4.1'
#[ -z ${} ] && =''

# clone
vm_clone ${DUMMY} ${NAME} ${SSHUSER} || die "failed to clone"
vm_start ${NAME} > /dev/null 2>&1 || die "failed to start ${NAME}"
ip=$(vm_getip ${NAME}) || die "failed to get ip ${NAME}"
vm_waitforssh ${NAME} ${KEYFILE} ${SSHUSER} > /dev/null 2>&1 || die "failed to ssh ${NAME}"
#ssh -oStrictHostKeyChecking=no -i ${KEYFILE} ${SSHUSER}@${ip} "rm /etc/telegraf/telegraf.d/*"
cat > "install-${NAME}.bash" <<EOF
# $(date) created with $0
dnf -y install wget
wget -q https://dl.influxdata.com/influxdb/releases/influxdb-${IFLUXDBVERSION}.x86_64.rpm
yum -y localinstall influxdb-${IFLUXDBVERSION}.x86_64.rpm
mv /etc/influxdb/influxdb.conf /etc/influxdb/influxdb.conf.orig
cat > /etc/influxdb/influxdb.conf <<TEXZ
reporting-disabled = true
[meta]
  dir = "/var/lib/influxdb/meta"
[data]
  dir = "/var/lib/influxdb/data"
  wal-dir = "/var/lib/influxdb/wal"
[[udp]]
  enabled = true
  database = "telegraf"
TEXZ
systemctl enable influxdb
systemctl start influxdb
wget -q https://dl.influxdata.com/chronograf/releases/chronograf-${CHRONOGRAFVERSION}.x86_64.rpm
yum -y localinstall chronograf-${CHRONOGRAFVERSION}.x86_64.rpm
systemctl enable chronograf
systemctl start chronograf
wget -q https://dl.influxdata.com/kapacitor/releases/kapacitor-${KAPACITORVERSION}.x86_64.rpm
yum -y localinstall kapacitor-${KAPACITORVERSION}.x86_64.rpm
systemctl enable kapacitor
systemctl start kapacitor
EOF
scp -oStrictHostKeyChecking=no -i ${KEYFILE} "install-${NAME}.bash" ${SSHUSER}@${ip}:
ssh -oStrictHostKeyChecking=no -i ${KEYFILE} ${SSHUSER}@${ip} "bash install-${NAME}.bash"
