#!/usr/bin/env bash
#
# install virsh if missing
#

log() { echo "$(date) $0: $*"; }
die() { log ": $*" >&2; exit 1; }

[ "$EUID" -ne 0 ] && die "Please run as root"

DEBUGLOG=/tmp/$0.log

virsh list --all >> $DEBUGLOG 2>&1
if [ $? -ne 0 ]; then
  log "installing virsh"
  apt --help > /dev/null 2>&1
  if [ $? -eq 0 ]; then
    apt-get -y install qemu-kvm libvirt-bin libvirt-dev ubuntu-vm-builder bridge-utils >> $DEBUGLOG 2>&1
    systemctl stop libvirt-guests.service >> $DEBUGLOG 2>&1
    systemctl stop libvirt-bin.service >> $DEBUGLOG 2>&1
    ## change default images location
    mkdir -p $IMAGESDIR
    chown libvirt-qemu $IMAGESDIR
    [ -d /var/lib/libvirt/images ] && rmdir /var/lib/libvirt/images
    [ -f /var/lib/libvirt/images ] && rm /var/lib/libvirt/images
    ln -s $IMAGESDIR /var/lib/libvirt/images
    chown libvirt-qemu /var/lib/libvirt/images
    systemctl enable libvirt-bin.service >> $DEBUGLOG 2>&1
    systemctl start libvirt-bin.service >> $DEBUGLOG 2>&1
    systemctl enable libvirt-guests.service >> $DEBUGLOG 2>&1
    systemctl start libvirt-guests.service >> $DEBUGLOG 2>&1
  fi
  dnf --help > /dev/null 2>&1
  if [ $? -eq 0 ]; then
    dnf -4 -q -y install @virtualization
    systemctl enable libvirtd
    systemctl start libvirtd
  fi
  virsh list --all >> $DEBUGLOG 2>&1
  if [ $? -ne 0 ]; then
    die "failed to install virsh"
  fi
  log "installed virsh"
fi
