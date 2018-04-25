#!/bin/bash
#
# enroll fedora guest
# if vm not exists, create new
# params:
#   INSTALLSCRIPT
#   NAME
# defaults or hardcoded
#   PARENT
#   IDMSERVER
#   LOGSERVER
#   INFLUXSERVER



log() { echo "$(date) $0: $*"; }
die() { log ": $*" >&2; exit 1; }

shortname(){ echo "$1"|cut -f1 -d. ; }
canping() { ping -c1 $1 > /dev/null 2>&1 && return 0; ping -c1 $(vm_getip $1) > /dev/null 2>&1 && return 0; return 1;}

[ "$EUID" -ne 0 ] && die "Please run as root"
SCRIPTS="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
VMHELPERS="${SCRIPTS}/../common/vmHelpers.bash"
[ -f ${VMHELPERS} ] || die "missing ${VMHELPERS}"
source ${VMHELPERS}

# INSTALLSCRIPT
[ -z $1 ] && die 'no install script'
INSTALLSCRIPT=$1
[ -f ${INSTALLSCRIPT} ] || die "missing ${INSTALLSCRIPT}"
[ $(file ${INSTALLSCRIPT}|grep "ASCII text executable"|wc -l) -ne 1 ] && die "not ASCII text executable ${INSTALLSCRIPT}"
# NAME
[ -z $2 ] && die 'no name'
NAME=$2
host ${NAME} >/dev/null 2>&1
[ $? -eq 0 ] && die 'name taken'
# defaults
DEFAULTS="${SCRIPTS}/../defaults"
[ -f ${DEFAULTS} ] && source ${DEFAULTS}
[ -f ${DEFAULTS} ] && log "loading params from  ${DEFAULTS}"
[ -f ${DEFAULTS} ] || log "using hardcoded params, as missing defaults ${DEFAULTS}"
[ -z ${DUMMY} ] && DUMMY='fedora-dummy'
[ -z $3 ] || DUMMY=$3
PARENT=${DUMMY}
vm_exists ${PARENT} || die "no parent ${PARENT}"

[ -z ${SSHUSER} ] && SSHUSER='root'
KEYFILE="${SSHUSER}.key"
[ -f ${KEYFILE} ] || die "no key file ${KEYFILE} for user ${SSHUSER}"
#ipa
[ -z ${IDMDOMAIN} ] && IDMDOMAIN="idm.organization.topleveldomain"
[ -z ${IDMSERVER} ] && IDMSERVER="freeipa-x.${IDMDOMAIN}"
[ -z $4 ] || IDMSERVER=$4
#TODO find out new IDMDOMAIN from $3
canping ${IDMSERVER} || die "cannot ping ${IDMSERVER}"
[ -z ${ENROLL} ] && ENROLL='hostenroll'
[ -f ${ENROLL}.passwd ] || die "no passwd for ${ENROLL}"
ENROLLPASSWORD=$(cat ${ENROLL}.passwd)
[ -z ${ADMIN} ] && ADMIN='sysadm'
[ -f ${ADMIN}.passwd ] || die "no passwd for ${ADMIN}"
ADMINPASSWORD=$(cat ${ADMIN}.passwd)
#syslog
[ -z ${LOGSERVER} ] && LOGSERVER="syslog-x.monitoring.organization.topleveldomain"
[ -z $5 ] || LOGSERVER=$5
canping  ${LOGSERVER} || die "cannot ping ${LOGSERVER}"
# metrix
[ -z ${INFLUXSERVER} ] && INFLUXSERVER="influx-x.monitoring.organization.topleveldomain"
[ -z $6 ] || INFLUXSERVER=$6
canping ${INFLUXSERVER} || die "cannot ping ${INFLUXSERVER}"
[ -z ${TELEGRAFVERSION} ] && TELEGRAFVERSION='telegraf-1.6.0-1'


if ! vm_exists ${NAME}; then
  log "creating new ${NAME} from ${PARENT}"
  vm_clone ${PARENT} ${NAME} ${SSHUSER} || die "failed to clone from ${PARENT}"
fi
vm_start ${NAME} > /dev/null || die "failed to start ${NAME}"
ip=$(vm_getip ${NAME}) || die "failed to get ip for ${NAME}"
vm_waitforssh ${NAME} ${USER}.key ${USER} > /dev/null || die "failed ssh to ${NAME}"
cat > install-guest-${NAME}.bash <<EOF
#!/bin/bash
# created $(date) by $0
shortname(){ echo "$1"|cut -f1 -d. ; }
LC_ALL="";

#echo "${IPAIP} ${IDMSERVER}" >> /etc/hosts
ping -c1 ${IDMSERVER} > /dev/null
if ! host ${IDMSERVER}; then
  if ! host $(shortname ${IDMSERVER}); then
    echo "can not resolve ${IDMSERVER}"
    exit 1
  else
      IDMSERVER=$(shortname ${IDMSERVER})
  fi
fi
  #wait for domain
  domain=\$(hostname -d|wc -l)
  counter=0
  while  [ \$domain -ne 1 -a \$counter -lt 10 ]; do
    let counter++
    sleep 3
    domain=\$(hostname -d|wc -l)
  done
  if [ \$(hostname -d|wc -l) -ne 1 ]; then
    echo "failed to get domain for ${NAME}"
    exit 1
  fi
  hn="\$(hostname -f)"
  echo "\$hn > /etc/hostname"
  hostname \$hn
  dnf -y install ipa-client;
  ipa-client-install -p ${ENROLL} -w ${ENROLLPASSWORD} --domain ${IDMDOMAIN} --server ${IDMSERVER} --fixed-primary --no-ntp --force --unattended --force-join || exit 1
  echo "${ADMINPASSWORD}" | kinit ${ADMIN}
  if [ $? -eq 0 ]; then
      klist
  else
    echo "ERROR, can not log in as ${ADMIN}"
    exit 1
  fi

telegraf --help > /dev/null 2>&1
if [ $? -ne 0 ]; then
  wget -q https://dl.influxdata.com/telegraf/releases/telegraf-${TELEGRAFVERSION}.x86_64.rpm
  yum -y localinstall telegraf-${TELEGRAFVERSION}.x86_64.rpm
  mv /etc/telegraf/telegraf.conf /etc/telegraf/telegraf.conf.orig
  cat > /etc/telegraf/telegraf.conf  <<TEWZ
  [global_tags]
  [agent]
    interval = "10s"
    round_interval = true
    metric_batch_size = 1000
    metric_buffer_limit = 10000
    collection_jitter = "0s"
    flush_interval = "10s"
    flush_jitter = "0s"
    precision = "s"
    debug = false
    quiet = false
    logfile = ""
    hostname = ""
    omit_hostname = false
  [[inputs.cpu]]
    percpu = true
    totalcpu = true
    collect_cpu_time = false
    report_active = false
  [[inputs.disk]]
    ignore_fs = ["tmpfs", "devtmpfs", "devfs"]
  [[inputs.diskio]]
  [[inputs.kernel]]
  [[inputs.mem]]
  [[inputs.processes]]
  [[inputs.swap]]
  [[inputs.system]]
  [[inputs.net]]
  [[inputs.netstat]]
TEWZ
  systemctl enable telegraf
fi
# remove any previous influxdb server
rm /etc/telegraf/telegraf.d/*
cat > /etc/telegraf/telegraf.d/${INFLUXSERVER}.conf <<TEWX
[[outputs.influxdb]]
urls = ["udp://${INFLUXSERVER}:8089"]
TEWX
systemctl restart telegraf
yum -y install rsyslog
# remove any previous syslog remote server
mv /etc/rsyslog.conf /etc/rsyslog.conf.${NAME}
grep -v "\*\.\*" /etc/rsyslog.conf.${NAME} > /etc/rsyslog.conf
echo "*.* @${LOGSERVER}:514" >> /etc/rsyslog.conf
systemctl restart syslog
EOF
scp -i ${USER}.key install-guest-${NAME}.bash ${USER}@${ip}:
ssh -i ${USER}.key ${USER}@${ip} "sudo bash install-guest-${NAME}.bash"
[ $? -ne 0 ] && die "failed enroll ${NAME}"
scp -i ${USER}.key ${INSTALLSCRIPT} ${USER}@${ip}:
ssh -i ${USER}.key ${USER}@${ip} "sudo bash $(basename ${INSTALLSCRIPT})"
[ $? -ne 0 ] && die "failed install ${INSTALLSCRIPT}"
