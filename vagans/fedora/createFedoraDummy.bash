#!/bin/bash
#
# creates FEDORA 27 image from scratch with virt-install
#


log() { echo "$(date) $(basename $0): $*"; }
die() { log "$*" >&2; exit 1; }

export LC_ALL=C


USERNAME='root'
[ -z $1 ] || USERNAME=$1
NAME='dummy-fedora'
[ -z $2 ] || NAME=$2
SCRIPTS="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
HELPERS="${SCRIPTS}/../common/vmHelpers.bash"
log "starting with ${USERNAME} ${NAME}"
[ -f ${HELPERS} ] || die "missing ${HELPERS}"
source ${HELPERS}
DEFAULTS="${SCRIPTS}/../defaults"
[ -f ${DEFAULTS} ] || die "missing ${DEFAULTS}"
source ${DEFAULTS}

#vm_exists ${NAME} && vm_delete ${NAME} > /dev/null
vm_exists ${NAME} && die "vm exists ${NAME}"
[ -f ${USERNAME}.key ] || ssh-keygen -t rsa -N "" -f ./${USERNAME}.key > /dev/null
[ -f ${USERNAME}.key ] || die "can not create ${USERNAME}.key"
[ -f ${USERNAME}.key.pub ] || die "can not find pubkey ${USERNAME}.key.pub"

LOCATION='https://www.mirrorservice.org/sites/dl.fedoraproject.org/pub/fedora/linux/releases/27/Server/x86_64/os/'
OS_TYPE="linux"
OS_VARIANT="fedora27"
PUBKEY=$(cat ${USERNAME}.key.pub)

cat > kickstartFedora27.cfg <<EOF
# Automatically created $(date) with $0
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
%end

%post --interpreter /bin/bash
set -x
exec >/var/log/kickstart-post.log 2>&1
yum -y install net-tools snoopy telegraf rsyslog ipa-client
yum -y update
mkdir /root/.ssh
echo "$PUBKEY" > /root/.ssh/authorized_keys
echo "$NAME.$DOMAIN" > /etc/hostname
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
find /var/log -maxdepth 1 -type f -exec cp /dev/null {} \;
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
/root/whiteout.bash
%end
EOF

virt-install \
--connect=qemu:///system \
--name=${NAME} \
--ram=2048 \
--vcpus=2 \
--os-type ${OS_TYPE} \
--disk size=16,path=/var/lib/libvirt/images/${NAME}.qcow2,format=qcow2,bus=virtio,cache=none \
--location ${LOCATION} \
--initrd-inject=kickstartFedora27.cfg \
--virt-type=kvm \
--controller usb,model=none \
--graphics none \
--network network=default,model=virtio \
--wait=-1 \
--noreboot \
--extra-args="auto=true ks=file:/kickstartFedora27.cfg console=tty0 console=ttyS0,115200n8 serial" > /dev/null 2&>1
[ $? -ne 0 ] && die "failed to create dummy ${NAME}"
imagefile=$(vm_getimagefile ${NAME})
[ -f $imagefile ] || die "fail does not exists $imagefile"
mv $imagefile $imagefile.backup
qemu-img convert -O qcow2 -c $imagefile.backup $imagefile > /dev/null
rm $imagefile.backup
virsh dumpxml ${NAME} > ${NAME}.xml
log "created ${NAME} KEY FILES ${USERNAME}.key && ${USERNAME}.key.pub"
