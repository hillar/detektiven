#!/usr/bin/env bash
#
# install virsh if missing
#

log() { echo "$(date) $(basename $0): $*"; }
die() { log "$*" >&2; exit 1; }

[ "$EUID" -ne 0 ] && die "Please run as root"

DEBUGLOG=/tmp/ensure-Virsh.log

virsh list --all >> $DEBUGLOG 2>&1
if [ $? -ne 0 ]; then
  [ -z $1 ] || IMAGESDIR=$1
  [ -z $IMAGESDIR ] && die "no images directory"
  log "installing virsh, images directory $IMAGESDIR"
  apt --help > /dev/null 2>&1
  if [ $? -eq 0 ]; then
    apt-get -y install virtinst qemu-kvm qemu-utils libvirt-bin libvirt-dev ubuntu-vm-builder bridge-utils libguestfs-tools >> $DEBUGLOG 2>&1
    systemctl stop libvirt-guests.service >> $DEBUGLOG 2>&1
    systemctl stop libvirt-bin.service >> $DEBUGLOG 2>&1
    ## change default images location
    mkdir -p $IMAGESDIR
    [ -d $IMAGESDIR ] || die "can not create images directory $IMAGESDIR"
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
    dnf -4 -y install @virtualization >> $DEBUGLOG 2>&1
    dnf -4 -y install libguestfs-tools >> $DEBUGLOG 2>&1
    ## change default images location
    mkdir -p $IMAGESDIR
    [ -d $IMAGESDIR ] || die "can not create images directory $IMAGESDIR"
    chown qemu $IMAGESDIR
    [ -d /var/lib/libvirt/images ] && rmdir /var/lib/libvirt/images
    [ -f /var/lib/libvirt/images ] && rm /var/lib/libvirt/images
    ln -s $IMAGESDIR /var/lib/libvirt/images
    chown qemu /var/lib/libvirt/images
    systemctl enable libvirtd >> $DEBUGLOG 2>&1
    systemctl start libvirtd >> $DEBUGLOG 2>&1
  fi
  virsh list --all >> $DEBUGLOG 2>&1
  if [ $? -ne 0 ]; then
    die "failed to install virsh"
  fi
  virsh net-autostart default >> $DEBUGLOG 2>&1
  log "installed virsh"
fi
