#!/bin/bash
#
# detektiven in the box
#

IMAGESDIR='/nvme/libvirt/images'


echo "$(date) starting $0"

XENIAL=$(lsb_release -c | cut -f2)
if [ "$XENIAL" != "xenial" ]; then
    echo "sorry, tested only with xenial ;(";
    exit;
fi

if [ "$(id -u)" != "0" ]; then
   echo "ERROR - This script must be run as root" 1>&2
   exit 1
fi

[ -d /provision ] || mkdir -p /provision



# libvirt
apt-get -y install qemu-kvm libvirt-bin libvirt-dev ubuntu-vm-builder bridge-utils
systemctl stop libvirt-guests.service
systemctl stop libvirt-bin.service
## change default images location
mkdir -p $IMAGESDIR
chown libvirt-qemu $IMAGESDIR
rmdir /var/lib/libvirt/images
ln -s $IMAGESDIR /var/lib/libvirt/images
chown libvirt-qemu /var/lib/libvirt/images
systemctl enable libvirt-bin.service
systemctl start libvirt-bin.service
systemctl enable libvirt-guests.service
systemctl start libvirt-guests.service
