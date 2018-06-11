#!/bin/bash
#
# creates ubuntu 18.04 image from scratch with virt-install
#

log() { echo "$(date) $(basename $0): $*"; }
die() { log "$*" >&2; exit 1; }

export LC_ALL=C

USERNAME='sysadmin'
[ -z $1 ] || USERNAME=$1
NAME='ubuntu-bionic-dummy'
[ -z $2 ] || NAME=$2
SCRIPTS="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
HELPERS="${SCRIPTS}/../common/vmHelpers.bash"
[ -f ${HELPERS} ] || die "missing ${HELPERS}"
source ${HELPERS}
log "starting with ${USERNAME} ${NAME}"
DEFAULTS="${SCRIPTS}/../defaults"
[ -f ${DEFAULTS} ] && source ${DEFAULTS}
[ -f ${DEFAULTS} ] && log "loading params from  ${DEFAULTS}"
[ -f ${DEFAULTS} ] || log "using hardcoded params, as missing defaults ${DEFAULTS}"
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
[ -z ${IMAGESPOOL} ] && IMAGESPOOL=$(virsh pool-list --name | head -1 | awk '{print $1}')
[ -z ${RAM} ] && RAM=2048
[ -z ${CPUS} ] && CPUS=2
[ -z ${DISKSIZE} ] && DISKSIZE="16G"

vm_exists ${NAME} && die "vm exists ${NAME}"
[ -f ${USERNAME}.key ] || ssh-keygen -t rsa -N "" -f ./${USERNAME}.key > /dev/null
[ -f ${USERNAME}.key ] || die "can not create ${USERNAME}.key"
[ -f ${USERNAME}.key.pub ] || die "can not find pubkey ${USERNAME}.key.pub"


LOCATION="http://us.archive.ubuntu.com/ubuntu/dists/bionic/main/installer-amd64/"
OS_TYPE="linux"
OS_VARIANT="ubuntu16.04"
# Error validating install location: Distro 'ubuntu18.04' does not exist in our dictionary
PUBKEY=$(cat ${USERNAME}.key.pub)
PASSWORD=$(cat /dev/urandom | tr -dc 'a-zA-Z0-9' | fold -w 32 | head -n 1)



cat > postinstall.bash <<EOF
#!/bin/bash
# Automatically created $(date) with $0
echo "\$(date) \$0: starting whiteout"
# Cleanup apt cache
apt-get -y autoremove --purge
apt-get -y clean
apt-get -y autoclean
# Cleanup DHCP
if [ -d "/var/lib/dhcp" ]; then
    rm /var/lib/dhcp/*
fi
# Cleanup tmp
rm -rf /tmp/*
# Clean up log files
find /var/log -maxdepth 1 -type f -exec cp /dev/null {} \;
find /var/log/apt -maxdepth 1 -type f -exec cp /dev/null {} \;
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
EOF

cat > preseed.${NAME}.cfg <<EOF
# Automatically created $(date) with $0
# ------------------------------------------------------------------------------
# This preseed file is designed for Ubuntu 16.04 (although it might work
# with other Ubuntu releases as well). It runs unattended, and generates
# a minimal Ubuntu Xenial installation with SSH and not much else.
#
# The installation wipes out anything that might have been on the primary disk
# and repartitions it with LVM and the 'atomic' partition scheme.
#
# Some values of interest:
#        Time zone: UTC
#   Other packages: bash-completion
#           Kernel: linux-virtual
#        Main user: ${USERNAME} (password: ${USERNAME})
#         Hostname: ${NAME}
#           Domain: (none)
# ------------------------------------------------------------------------------

# Kernel Selection
d-i base-installer/kernel/override-image string linux-virtual

# Boot Setup
d-i debian-installer/quiet boolean false
d-i debian-installer/splash boolean false
d-i grub-installer/timeout string 2

# Locale Setup
d-i pkgsel/language-pack-patterns string
d-i pkgsel/install-language-support boolean false

d-i debian-installer/language string en
d-i debian-installer/country string US
d-i debian-installer/locale string en_US.UTF-8

# Keyboard Setup
d-i console-setup/ask_detect boolean false
d-i keyboard-configuration/layoutcode string us

# Clock Setup
d-i time/zone string UTC
d-i clock-setup/utc-auto boolean true
d-i clock-setup/utc boolean true
d-i clock-setup/ntp boolean true

# Network Setup
# Note that the hostname and domain also need to be passed as
# arguments on the installer init line.
d-i netcfg/get_hostname string ${NAME}
d-i netcfg/get_domain string ${DOMAIN}
# Choose an network interface that has link if possible.
d-i netcfg/choose_interface select auto

### Mirror settings
d-i mirror/http/countries select EE
d-i mirror/country string EE
d-i mirror/http/hostname string ee.archive.ubuntu.com
d-i mirror/http/directory string /images/Ubuntu/18.04
d-i mirror/http/mirror select ee.archive.ubuntu.com
d-i mirror/http/proxy string
#d-i mirror/protocol string ftp
#d-i mirror/suite string bionic
#d-i mirror/udeb/suite string bionic
#d-i mirror/udeb/components multiselect main, restricted

# Drive Setup
d-i grub-installer/only_debian boolean true
d-i partman/unmount_active boolean true
#d-i preseed/early_command string umount /media
d-i partman-lvm/device_remove_lvm boolean true
d-i partman-md/device_remove_md boolean true
#d-i partman-auto/disk string /dev/vda
d-i partman-auto/method string lvm
d-i partman-partitioning/confirm_write_new_label boolean true
d-i partman/confirm boolean true
d-i partman/confirm_nooverwrite boolean true
d-i partman-lvm/confirm boolean true
d-i partman-lvm/confirm_nooverwrite boolean true
d-i partman-auto-lvm/new_vg_name string primary
d-i partman-auto-lvm/guided_size string max
d-i partman-auto/choose_recipe select atomic
d-i partman/mount_style select uuid
d-i partman/choose_partition select finish

# User Setup
d-i user-setup/allow-password-weak boolean true
d-i passwd/user-fullname string ${USERNAME}
d-i passwd/username string ${USERNAME}

d-i passwd/user-password ${PASSWORD} ${PASSWORD}
d-i passwd/user-password-again ${PASSWORD} ${PASSWORD}
d-i user-setup/allow-password-weak boolean true
d-i user-setup/encrypt-home boolean false

# Repository Setup
d-i apt-setup/restricted boolean true
d-i apt-setup/universe boolean true
d-i apt-setup/backports boolean true

# Do not install recommended packages by default.
d-i base-installer/install-recommends boolean false

# Package Setup
tasksel tasksel/skip-tasks string standard
tasksel tasksel/first multiselect
d-i hw-detect/load_firmware boolean false
d-i pkgsel/update-policy select none
d-i pkgsel/include string openssh-server bash-completion acpi-support wget
d-i pkgsel/upgrade select full-upgrade

# add ${USERNAME} to sudoers and copy ssh key
d-i preseed/late_command string mkdir -p /target/home/${USERNAME}/.ssh; echo '$PUBKEY' >> /target/home/${USERNAME}/.ssh/authorized_keys; echo '${USERNAME} ALL=NOPASSWD:ALL' > /target/etc/sudoers.d/${USERNAME}

# Avoid that last message about the install being complete.
d-i finish-install/reboot_in_progress note

# Perform a poweroff instead of a reboot
d-i debian-installer/exit/poweroff boolean true
EOF

[ -f preseed.${NAME}.cfg ] || die 'can not create preseed.${NAME}.cfg'

log "Please be patient. This may take a few minutes ..."

#check pool

if virsh pool-info ${IMAGESPOOL} ; then
  #ve=$(virsh vol-list --pool ${POOL} --details | grep " $FILE " | wc -l)
  #if [ $ve -ne 1 ]; then
    virsh vol-create-as ${IMAGESPOOL} ${NAME}-vda --capacity ${DISKSIZE} --format raw
  #fi
  virt-install \
  --connect=qemu:///system \
  --name=${NAME} \
  --ram=${RAM} \
  --vcpus=${CPUS} \
  --os-type ${OS_TYPE} \
  --os-varian ${OS_VARIANT} \
  --location ${LOCATION} \
  --initrd-inject=preseed.${NAME}.cfg \
  --disk vol=${IMAGESPOOL}/${NAME}-vda \
  --virt-type=kvm \
  --controller usb,model=none \
  --graphics none \
  --network bridge=br0,model=virtio \
  --network network=default,model=virtio \
  --wait=-1 \
  --noreboot \
  --extra-args="auto=true hostname="${NAME}" domain="${DOMAIN}" file=file:preseed.${NAME}.cfg console=tty0 console=ttyS0,115200n8 serial"

else
  virt-install \
  --connect=qemu:///system \
  --name=${NAME} \
  --ram=${RAM} \
  --vcpus=${CPUS} \
  --os-type ${OS_TYPE} \
  --os-varian ${OS_VARIANT} \
  --disk size=${DISKSIZE},path=/var/lib/libvirt/images/${NAME}.qcow2,format=qcow2,bus=virtio,cache=none \
  --location ${LOCATION} \
  --initrd-inject=preseed.${NAME}.cfg \
  --virt-type=kvm \
  --controller usb,model=none \
  --graphics none \
  --network bridge=br0,model=virtio \
  --network network=default,model=virtio \
  --wait=-1 \
  --noreboot \
  --extra-args="auto=true hostname="${NAME}" domain="${DOMAIN}" file=file:preseed.${NAME}.cfg console=tty0 console=ttyS0,115200n8 serial"
  [ $? -ne 0 ] && die "failed to create dummy ${NAME}"
  imagefile=$(vm_getimagefile ${NAME})
  [ -f $imagefile ] || die "fail does not exists $imagefile"
  #mv $imagefile $imagefile.backup
  #qemu-img convert -O qcow2 -c $imagefile.backup $imagefile > /dev/null
  #rm $imagefile.backup
fi
virsh dumpxml ${NAME} > ${NAME}.xml
log "created ${NAME} KEY FILES ${USERNAME}.key && ${USERNAME}.key.pub"
