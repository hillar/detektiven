#!/bin/bash
#
# detektiven in the box
#
# ;) read before running it
# also see https://github.com/hillar/detektiven/blob/master/vagans/README.md

XENIAL=$(lsb_release -c | cut -f2)
if [ "$XENIAL" != "xenial" ]; then
    echo "sorry, tested only with xenial ;(";
    exit;
fi

if [ "$(id -u)" != "0" ]; then
   echo "ERROR - This script must be run as root" 1>&2
   exit 1
fi

log() { echo "$(date) $0: $*"; }
die() { log ": $*" >&2; exit 1; }

DIR='/nvme/libvirt'
[ -z $1 ] || DIR=$1
log " starting with DIR=$DIR"
[ -d $DIR ] || mkdir -p $DIR
[ -d $DIR ] || die "can not create $DIR"
IMAGESDIR="$DIR/images"
BOXESDIR="$DIR/boxes"
USERNAME='dummy'
export SYSTEMD_PAGER=''
export LC_ALL=C
export DEBIAN_FRONTEND=noninteractive

# debug log
[ -d  $BOXESDIR/log ] || mkdir -p $BOXESDIR/log
DEBUGLOG="$BOXESDIR/log/debug.$(date +%Y%m%d%H%M%S)"

# libvirt
virsh list --all >> $DEBUGLOG 2>&1
if [ $? -ne 0 ]; then
  log " installing virsh "
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
  virsh list --all >> $DEBUGLOG 2>&1
  if [ $? -ne 0 ]; then
    die "installing virsh failed"
  fi
fi

# boxes
[ -d  $BOXESDIR/scripts ] || mkdir -p $BOXESDIR/scripts
cd $BOXESDIR/scripts

[ -f setup.bash ] && rm setup.bash
[ -f virtHelpers.bash ] && rm virtHelpers.bash
[ -f createDummy.bash ] && rm createDummy.bash

[ -f  $BOXESDIR/scripts/setup.bash ] || wget --no-check-certificate -q https://raw.githubusercontent.com/hillar/detektiven/master/vagans/setup.bash
[ -f  $BOXESDIR/scripts/setup.bash ] || die "missing setup.bash"
[ -f  $BOXESDIR/scripts/virtHelpers.bash ] || wget --no-check-certificate -q https://raw.githubusercontent.com/hillar/detektiven/master/vagans/virtHelpers.bash
[ -f  $BOXESDIR/scripts/virtHelpers.bash ] || die "missing virtHelpers.bash"
[ -f  $BOXESDIR/scripts/createDummy.bash ] || wget --no-check-certificate -q https://raw.githubusercontent.com/hillar/detektiven/master/vagans/createDummy.bash
[ -f  $BOXESDIR/scripts/createDummy.bash ] || die "missing createDummy.bash"
source $BOXESDIR/scripts/virtHelpers.bash

cd $BOXESDIR

DUMMY='dummy'
if [ ! $(vm_exists ${DUMMY}) = '0' ]; then
  log "creating very first dummy"
  bash $BOXESDIR/scripts/createDummy.bash ${USERNAME} $BOXESDIR/scripts/virtHelpers.bash >> $DEBUGLOG 2>&1
  virsh dumpxml ${DUMMY} > ${DUMMY}.xml
fi
[ ! $(vm_exists ${DUMMY}) = '0' ] && die "can not create ${DUMMY}"
stop_vm ${DUMMY}

FB='firstborn'
if [ ! $(vm_exists ${FB}) = '0' ]; then
  log "creating first clone from dummy"
  virt-clone -q -o ${DUMMY} -n ${FB} --auto-clone
  compress_vm ${FB}
fi
[ ! $(vm_exists ${FB}) = '0' ] && die "can not create ${FB}"
stop_vm ${FB}

[ -f ${USERNAME}.key ] || die "missing ${USERNAME}.key"

JAVA='preinstalled.java'
if [ ! $(vm_exists ${JAVA}) = '0' ]; then
  log " creating preinstalled java"
  virt-clone -q -o ${FB} -n ${JAVA} --auto-clone
  start_vm ${JAVA}
  java_ip=$(getip_vm ${JAVA})
  ssh-keygen -f "/root/.ssh/known_hosts" -R ${java_ip}
  ssh -oStrictHostKeyChecking=no -i ${USERNAME}.key ${USERNAME}@${java_ip} "sudo su -c 'echo ${JAVA} > /etc/hostname'"
  [ -f  $BOXESDIR/scripts/install-java.bash ] || wget --no-check-certificate -q https://raw.githubusercontent.com/hillar/detektiven/master/vagans/install-java.bash -O $BOXESDIR/scripts/install-java.bash
  [ -f  $BOXESDIR/scripts/install-java.bash ] || die "missing install-java.bash"
  scp -i ${USERNAME}.key $BOXESDIR/scripts/install-java.bash ${USERNAME}@${java_ip}:
  ssh -oStrictHostKeyChecking=no -i ${USERNAME}.key ${USERNAME}@${java_ip} "sudo bash -x /home/${USERNAME}/install-java.bash " >> $DEBUGLOG 2>&1
  ssh -oStrictHostKeyChecking=no -i ${USERNAME}.key ${USERNAME}@${java_ip} "sudo bash -x /home/${USERNAME}/postinstall.bash" >> $DEBUGLOG 2>&1
  stop_vm ${JAVA}
  virsh dumpxml ${JAVA} > ${JAVA}.xml
  compress_vm ${JAVA}
fi
[ ! $(vm_exists ${JAVA}) = '0' ] && die "can not create ${JAVA}"
stop_vm ${JAVA}

IPA='freeipa'
if [ ! $(vm_exists ${IPA}) = '0' ]; then
  log " creating IPA ${IPA}"
  virt-clone -q  -o ${JAVA} -n ${IPA} --auto-clone
  start_vm ${IPA}
  ipa_ip=$(getip_vm ${IPA})
  ssh-keygen -f "/root/.ssh/known_hosts" -R ${ipa_ip}
  ssh -oStrictHostKeyChecking=no -i ${USERNAME}.key ${USERNAME}@${ipa_ip} "sudo su -c 'echo ${IPA} > /etc/hostname'"
  [ -f $BOXESDIR/scripts/install-freeipa.bash ] || wget --no-check-certificate -q https://raw.githubusercontent.com/hillar/detektiven/master/freeipa/install-freeipa.bash -O $BOXESDIR/scripts/install-freeipa.bash
  [ -f $BOXESDIR/scripts/install-freeipa.bash ] || die "${IPA} missing install-freeipa.bash"
  scp -i ${USERNAME}.key $BOXESDIR/scripts/install-java.bash ${USERNAME}@${ipa_ip}:
  ssh -oStrictHostKeyChecking=no -i ${USERNAME}.key ${USERNAME}@${ipa_ip} "sudo bash -x /home/${USERNAME}/install-freeipa.bash ${ipa_ip}" >> $DEBUGLOG 2>&1
  ssh -oStrictHostKeyChecking=no -i ${USERNAME}.key ${USERNAME}@${ipa_ip} "sudo bash -x /home/${USERNAME}/postinstall.bash " >> $DEBUGLOG 2>&1
  stop_vm ${IPA}
  virsh dumpxml ${IPA} > ${IPA}.xml
  compress_vm ${IPA}
fi
[ ! $(vm_exists ${IPA}) = '0' ] && die "can not create ${IPA}"
start_vm ${IPA}
ipa_ip=$(getip_vm ${IPA})
sleep 2
ssh -oStrictHostKeyChecking=no -i ${USERNAME}.key ${USERNAME}@${ipa_ip} "netstat -ntple"
ipa80=$(curl -s ${ipa_ip} | wc -l)
if [ $ipa80 -ne 375 ]; then
   log " WARNING IPA ${IPA} ${ipa_ip} did not replied as expected"
fi

TIKA='tika'
if [ ! $(vm_exists ${TIKA}) = '0' ]; then
  log " creating TIKA ${TIKA}"
  virt-clone -q  -o ${JAVA} -n ${TIKA} --auto-clone
  start_vm ${TIKA}
  tika_ip=$(getip_vm ${TIKA})
  ssh-keygen -f "/root/.ssh/known_hosts" -R ${tika_ip}
  ssh -oStrictHostKeyChecking=no -i ${USERNAME}.key ${USERNAME}@${ipa_ip} "sudo su -c 'echo ${TIKA} > /etc/hostname'"
  [ -f $BOXESDIR/scripts/install-tika.bash ] || wget --no-check-certificate -q https://raw.githubusercontent.com/hillar/detektiven/master/stuff/txt/osse/tika/install-tika.bash -O $BOXESDIR/scripts/install-tika.bash
  [ -f $BOXESDIR/scripts/install-tika.bash ] || die "${TIKA} missing install-tika.bash"
  scp -i ${USERNAME}.key $BOXESDIR/scripts/install-tika.bash ${USERNAME}@${tika_ip}:
  ssh -oStrictHostKeyChecking=no -i ${USERNAME}.key ${USERNAME}@${tika_ip} "sudo bash -x /home/${USERNAME}/install-tika.bash ${tika_ip}" >> $DEBUGLOG 2>&1
  ssh -oStrictHostKeyChecking=no -i ${USERNAME}.key ${USERNAME}@${tika_ip} "sudo bash -x /home/${USERNAME}/postinstall.bash" >> $DEBUGLOG 2>&1
  stop_vm ${TIKA}
  virsh dumpxml ${TIKA} > ${TIKA}.xml
  compress_vm ${TIKA}
fi
[ ! $(vm_exists ${TIKA}) = '0' ] && die "can not create ${TIKA}"
start_vm ${TIKA}
tika_ip=$(getip_vm ${TIKA})
ssh -oStrictHostKeyChecking=no -i ${USERNAME}.key ${USERNAME}@${tika_ip} "netstat -ntple"
tika69=$(curl -s ${tika_ip}:9998 | wc -l)
if [ $tika69 -ne 69 ]; then
   log " WARNING TIKA ${TIKA} ${tika_ip} did not replied as expected"
fi
