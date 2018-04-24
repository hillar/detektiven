#!/usr/bin/env bash
# build syslog server on Fedora 27
# params NAME
# installing rsyslog (? elastic + kibana)
# listening for remote syslog's on udp port 514

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

# clone
vm_clone ${DUMMY} ${NAME} ${SSHUSER} || die "failed to clone"
vm_start ${NAME} > /dev/null 2>&1 || die "failed to start ${NAME}"
ip=$(vm_getip ${NAME}) || die "failed to get ip ${NAME}"
vm_waitforssh ${NAME} ${KEYFILE} ${SSHUSER} > /dev/null 2>&1 || die "failed to ssh ${NAME}"
#ssh -oStrictHostKeyChecking=no -i ${KEYFILE} ${SSHUSER}@${ip} "rm /etc/telegraf/telegraf.d/*"
cat > "install-${NAME}.bash" <<EOF
# $(date) created with $0
dnf -y install wget rsyslog
mv /etc/rsyslog.conf /etc/rsyslog.conf.orig

cat > /etc/rsyslog.conf <<TEXZ
# provides UDP syslog reception
module(load="imudp")
input(type="imudp" port="514")
# provides TCP syslog reception
module(load="imtcp")
input(type="imtcp" port="514")
# dir layout
\\\$template DYNremote,"/var/log/remote/%programname%/%\\\$YEAR%/%\\\$MONTH%/%\\\$DAY%/%hostname%.log"
if \
        \\\$source != 'localhost' \
then    ?DYNremote
global(workDirectory="/var/lib/rsyslog")
module(load="builtin:omfile" Template="RSYSLOG_TraditionalFileFormat")
include(file="/etc/rsyslog.d/*.conf" mode="optional")
*.info;mail.none;authpriv.none;cron.none                /var/log/messages
authpriv.*                                              /var/log/secure
mail.*                                                  -/var/log/maillog
cron.*                                                  /var/log/cron
*.emerg                                                 :omusrmsg:*
uucp,news.crit                                          /var/log/spooler
local7.*                                                /var/log/boot.log
TEXZ

systemctl enable syslog
systemctl restart syslog
EOF
scp -oStrictHostKeyChecking=no -i ${KEYFILE} "install-${NAME}.bash" ${SSHUSER}@${ip}:
ssh -oStrictHostKeyChecking=no -i ${KEYFILE} ${SSHUSER}@${ip} "bash install-${NAME}.bash"
