#!/bin/bash
#
# creates FEDORA 27 image from scratch with virt-install
#

log() { echo "$(date) $(basename $0): $*"; }
die() { log "$*" >&2; exit 1; }

export LC_ALL=C

USERNAME='root'
[ -z $1 ] || USERNAME=$1
NAME='fedora-dummy'
[ -z $2 ] || NAME=$2
SCRIPTS="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
HELPERS="${SCRIPTS}/../common/vmHelpers.bash"
[ -f ${HELPERS} ] || die "missing ${HELPERS}"
source ${HELPERS}
log "starting with ${USERNAME} ${NAME}"
DEFAULTS="${SCRIPTS}/../defaults"
[ -f ${DEFAULTS} ] && source ${DEFAULTS}
[ -f ${DEFAULTS} ] && log "loading params from  ${DEFAULTS}"
[ -f ${DEFAULTS} ] || log "using hardcoded prarams, as missing defaults ${DEFAULTS}"
[ -z ${DUMMY} ] && DUMMY='fedora-dummy'
NAME="${DUMMY}"
[ -z $2 ] || NAME=$2
[ -z $TLD ] && TLD='topleveldomain'
[ -z $ORG ] && ORG='organization'
[ -z $INFLUX ] && INFLUX='influx-x'
[ -z $MON ] && MON='monitoring'
[ -z $LOG ] && LOG='syslog-x'
[ -z ${INFLUXSERVER} ] && INFLUXSERVER="${INFLUX}.${MON}.${ORG}.${TLD}"
[ -z ${LOGSERVER} ] && LOGSERVER="${LOG}.${MON}.${ORG}.${TLD}"
[ -z ${TELEGRAFVERSION} ] && TELEGRAFVERSION='telegraf-1.6.0-1'

vm_exists ${NAME} && die "vm exists ${NAME}"
[ -f ${USERNAME}.key ] || ssh-keygen -t rsa -N "" -f ./${USERNAME}.key > /dev/null
[ -f ${USERNAME}.key ] || die "can not create ${USERNAME}.key"
[ -f ${USERNAME}.key.pub ] || die "can not find pubkey ${USERNAME}.key.pub"

LOCATION='https://www.mirrorservice.org/sites/dl.fedoraproject.org/pub/fedora/linux/releases/27/Server/x86_64/os/'
OS_TYPE="linux"
OS_VARIANT="fedora27"
PUBKEY=$(cat ${USERNAME}.key.pub)

cat > kickstartFedora27.${NAME}.cfg <<EOF
# Automatically created $(date) for ${NAME} with $0
text
install
lang en_GB.UTF-8
keyboard us
network --noipv6 --onboot=yes --bootproto=dhcp
timezone Europe/Tallinn --isUtc
auth --useshadow --enablemd5
selinux --disabled
firewall --disabled
services --enabled=sshd
eula --agreed
ignoredisk --only-use=vda
bootloader --location=mbr
zerombr
clearpart --all --initlabel
part swap --asprimary --fstype="swap" --size=1024
part /boot --fstype xfs --size=200
part pv.01 --size=1 --grow
volgroup rootvg01 pv.01
logvol / --fstype xfs --name=lv01 --vgname=rootvg01 --size=1 --grow
rootpw --plaintext centos
repo --name=base --baseurl=$LOCATION
url --url="$LOCATION"
reboot
firstboot --disabled

%packages --ignoremissing
@core --nodefaults
-aic94xx-firmware*
-alsa-*
-biosdevname
-btrfs-progs*
-dracut-network
-iprutils
-ivtv*
-iwl*firmware
-libertas*
-kexec-tools
-plymouth*
-postfix
net-tools
wget
%end

%post --interpreter /bin/bash
set -x
exec >/var/log/kickstart-post.log 2>&1
date
echo "$(date) born as ${NAME} roots ${LOCATION}" > /etc/birth.certificate
yum -y update
yum -y install ipa-client
yum -y install rsyslog
echo "*.* @${LOGSERVER}:514" >> /etc/rsyslog.conf
yum -y install snoopy
/usr/sbin/snoopy-enable
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
cat > /etc/telegraf/telegraf.d/${INFLUXSERVER}.conf <<TEWX
[[outputs.influxdb]]
urls = ["udp://${INFLUXSERVER}:8089"]
TEWX
mkdir /root/.ssh
echo "$PUBKEY" > /root/.ssh/authorized_keys
echo "$NAME" > /etc/hostname
cat > /root/whiteout.bash <<TEWC
#!/bin/bash
# Automatically created $(date) with $0
echo "\$(date) \$0: start whiteout"
# Cleanup yum
yum -y autoremove
yum -y clean all
rm -rf /var/cache/yum
# Cleanup tmp
rm -rf /tmp/*
# Clean up log files
#find /var/log -maxdepth 1 -type f -exec cp /dev/null {} \;
find /var/log/yum -maxdepth 1 -type f -exec cp /dev/null {} \;
find /var/log/fsck -maxdepth 1 -type f -exec cp /dev/null {} \;
journalctl --vacuum-time=1seconds
# Whiteout /boot
dd if=/dev/zero of=/boot/whitespace bs=1M || echo "dd exit code \$? is suppressed"
rm /boot/whitespace
# Whiteout /
dd if=/dev/zero of=/EMPTY bs=1M  || echo "dd exit code \$? is suppressed"
rm -f /EMPTY
# Make sure we wait until all the data is written to disk
sync
echo "\$(date) \$0: done whiteout"
TEWC
chmod +x /root/whiteout.bash
date
/root/whiteout.bash
date
%end
EOF
log "Please be patient. This may take a few minutes ..."
virt-install \
--connect=qemu:///system \
--name=${NAME} \
--ram=2048 \
--vcpus=2 \
--os-type ${OS_TYPE} \
--disk size=16,path=/var/lib/libvirt/images/${NAME}.qcow2,format=qcow2,bus=virtio,cache=none \
--location ${LOCATION} \
--initrd-inject=kickstartFedora27.${NAME}.cfg \
--virt-type=kvm \
--controller usb,model=none \
--graphics none \
--network network=default,model=virtio \
--wait=-1 \
--noreboot \
--extra-args="auto=true ks=file:/kickstartFedora27.${NAME}.cfg console=tty0 console=ttyS0,115200n8 serial" > /dev/null
[ $? -ne 0 ] && die "failed to create dummy ${NAME}"
imagefile=$(vm_getimagefile ${NAME})
[ -f $imagefile ] || die "fail does not exists $imagefile"
#mv $imagefile $imagefile.backup
#qemu-img convert -O qcow2 -c $imagefile.backup $imagefile > /dev/null
#rm $imagefile.backup
virsh dumpxml ${NAME} > ${NAME}.xml
log "created ${NAME} KEY FILES ${USERNAME}.key && ${USERNAME}.key.pub"
