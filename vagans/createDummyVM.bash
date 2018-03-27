apt-get -y install virtinst

NAME="dummy"
DOMAIN=`/bin/hostname -d`


cat > preseed.cfg <<EOF
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
#        Main user: dummyuser (password: dummyuser)
#         Hostname: dummy-xenial64
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
d-i netcfg/get_hostname string $NAME
d-i netcfg/get_domain string $DOMAIN
# Choose an network interface that has link if possible.
d-i netcfg/choose_interface select auto

### Mirror settings
d-i mirror/http/countries select EE
d-i mirror/country string EE
d-i mirror/http/hostname string ee.archive.ubuntu.com
d-i mirror/http/directory string /images/Ubuntu/16.04
d-i mirror/http/mirror select ee.archive.ubuntu.com
d-i mirror/http/proxy string

# Drive Setup
d-i grub-installer/only_debian boolean true
d-i partman/unmount_active boolean true
d-i preseed/early_command string umount /media
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
d-i passwd/user-fullname string dummyuser
d-i passwd/username string dummyuser

d-i passwd/user-password dummyuser dummyuser
d-i passwd/user-password-again dummyuser dummyuser
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
d-i pkgsel/include string openssh-server bash-completion
d-i pkgsel/upgrade select full-upgrade

# Run postinst.sh in /target just before the install finishes.
d-i preseed/late_command string cp postinst.sh /target/tmp/
d-i preseed/late_command string chmod 755 /target/tmp/postinst.sh
d-i preseed/late_command string in-target /tmp/postinst.sh

# Avoid that last message about the install being complete.
d-i finish-install/reboot_in_progress note
d-i debian-installer/exit/poweroff boolean true

EOF

cat > postinst.sh <<EOF
#!/bin/bash -eux

# Update the box
apt-get -y update
apt-get -y upgrade

# Set up sudo
echo 'dummyuser ALL=NOPASSWD:ALL' > /etc/sudoers.d/dummyuser

#sed -i 's/[ #]*GRUB_CMDLINE_LINUX=.*/GRUB_CMDLINE_LINUX="net.ifnames=0 biosdevname=0"/g' /etc/default/grub
#update-grub

SSH_USER=\${SSH_USERNAME:-dummyuser}

# Cleanup DHCP
if [ -d "/var/lib/dhcp" ]; then
    rm /var/lib/dhcp/*
fi

# Cleanup tmp
rm -rf /tmp/*

# Cleanup apt cache
apt-get -y autoremove --purge
apt-get -y clean
apt-get -y autoclean

# Remove Bash history
unset HISTFILE
rm -f /root/.bash_history
rm -f /home/\${SSH_USER}/.bash_history

# Clean up log files
find /var/log -maxdepth 1 -type f -exec cp /dev/null {} \;
find /var/log/apt -maxdepth 1 -type f -exec cp /dev/null {} \;
find /var/log/fsck -maxdepth 1 -type f -exec cp /dev/null {} \;
journalctl --vacuum-time=1seconds

# Whiteout root
count=\$(df --sync -kP / | tail -n1  | awk -F ' ' '{print \$4}')
let count--
dd if=/dev/zero of=/tmp/whitespace bs=1024 count=\$count
rm /tmp/whitespace

# Whiteout /boot
count=\$(df --sync -kP /boot | tail -n1 | awk -F ' ' '{print \$4}')
let count--
dd if=/dev/zero of=/boot/whitespace bs=1024 count=\$count
rm /boot/whitespace

# Whiteout swap partitions
set +e
swapuuid=\$(/sbin/blkid -o value -l -s UUID -t TYPE=swap)
case "\$?" in
    2|0) ;;
    *) exit 1 ;;
esac
set -e
if [ "x\${swapuuid}" != "x" ]; then
    # Whiteout the swap partition to reduce box size
    # Swap is disabled till reboot
    swappart=\$(readlink -f /dev/disk/by-uuid/\$swapuuid)
    /sbin/swapoff "\${swappart}"
    dd if=/dev/zero of="\${swappart}" bs=1M || echo "dd exit code \$? is suppressed"
    /sbin/mkswap -U "\${swapuuid}" "\${swappart}"
fi

# Zero out the free space to save space in the final image
dd if=/dev/zero of=/EMPTY bs=1M  || echo "dd exit code \$? is suppressed"
rm -f /EMPTY

# Make sure we wait until all the data is written to disk, otherwise
# Packer might quite too early before the large files are deleted
sync
EOF

OS_TYPE="linux"
OS_VARIANT="ubuntu16.04"

virt-install \
--connect=qemu:///system \
--name=${NAME} \
--ram=2048 \
--vcpus=2 \
--os-type $OS_TYPE \
--os-variant $OS_VARIANT \
--disk size=16,path=/var/lib/libvirt/images/${NAME}.img,bus=virtio,cache=none \
--initrd-inject=preseed.cfg \
--location http://us.archive.ubuntu.com/ubuntu/dists/xenial/main/installer-amd64/ \
--os-type linux \
--virt-type=kvm \
--controller usb,model=none \
--graphics none \
--network network=default,model=virtio \
--extra-args="auto=true hostname="${NAME}" domain="${DOMAIN}" console=tty0 console=ttyS0,115200n8 serial"
