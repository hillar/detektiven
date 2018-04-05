#!/bin/bash
#
# creates CENTOS 7.4.1708 image from scratch with virt-install
#

XENIAL=$(lsb_release -c | cut -f2)
if [ "$XENIAL" != "xenial" ]; then
    echo "sorry, tested only with xenial ;(";
    exit;
fi

log() { echo "$(date) $0: $*"; }
die() { log ": $*" >&2; exit 1; }

export LC_ALL=C


NAME='dummy-centos'
[ -z $1 ] || NAME=$1
USERNAME='dummy'
[ -z $2 ] || USERNAME=$2
SCRIPTS="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
HELPERS="${SCRIPTS}/virtHelpers.bash"
[ -z $3 ] || HELPERS=$3
[ -f ${HELPERS} ] || die "missing ${HELPERS}"
source ${HELPERS}

log "going to delete ${NAME}"
delete_vm ${NAME} > /dev/null
[ $(vm_exists ${NAME}) = '0' ] && die "can not delete vm ${NAME}"

[ -f ${USERNAME}.key ] || ssh-keygen -t rsa -N "" -f ./${USERNAME}.key > /dev/null
[ -f ${USERNAME}.key ] || die "can not create ${USERNAME}.key"
[ -f ${USERNAME}.key.pub ] || die "can not find pubkey ${USERNAME}.key.pub"

LOCATION='http://ftp.estpak.ee/pub/centos/7.4.1708/os/x86_64/'
OS_TYPE="linux"
OS_VARIANT="centos7.4"
PUBKEY=$(cat ${USERNAME}.key.pub)

cat > kickstart.cfg <<EOF
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

%packages --nobase --ignoremissing
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
-NetworkManager
%end

%post --interpreter /bin/bash
set -x
exec >/var/log/kickstart-post.log 2>&1
yum -y install net-tools
yum -y update
mkdir /root/.ssh
echo "$PUBKEY" > /root/.ssh/authorized_keys
echo "$NAME.$DOMAIN" > /etc/hostname
cat > /root/whiteoutCentos.bash <<TEWC
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
chmod +x /root/whiteoutCentos.bash
/root/whiteoutCentos.bash
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
--initrd-inject=kickstart.cfg \
--initrd-inject=${USERNAME}.key \
--virt-type=kvm \
--controller usb,model=none \
--graphics none \
--network network=default,model=virtio \
--wait=-1 \
--noreboot \
--extra-args="auto=true ks=file:/kickstart.cfg console=tty0 console=ttyS0,115200n8 serial"

imagefile=$(getfile_vm ${NAME})
mv $imagefile $imagefile.backup
qemu-img convert -O qcow2 -c $imagefile.backup $imagefile > /dev/null
rm $imagefile.backup
log "created vm: ${NAME} username: root key: ${USERNAME}.key"
