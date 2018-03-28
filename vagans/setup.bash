#!/bin/bash
#
# detektiven in the box
#

IMAGESDIR='/nvme/libvirt/images'
BOXESDIR='/sdb/boxes'

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

# boxes
[ -d  $BOXESDIR ] || mkdir -p $BOXESDIR
cd $BOXESDIR
mkdir dummy
cd dummy
wget --no-check-certificate -q https://raw.githubusercontent.com/hillar/detektiven/master/vagans/virtHelpers.bash
wget --no-check-certificate -q https://raw.githubusercontent.com/hillar/detektiven/master/vagans/createDummy.bash
source virtHelpers.bash

VM='dummy'
[ $(vm_exists ${VM}) = '0' ] || bash createDummy.bash
[ $(vm_is_running ${VM}) = '0' ] && stop_vm ${VM}

FB='firstborn'
[ $(vm_exists ${FB}) = '0' ] || virt-clone  -o ${VM} -n ${FB} --auto-clone

IPA='freeipa'
[ $(vm_exists ${IPA}) = '0' ] || virt-clone  -o ${FB} -n ${IPA} --auto-clone

start_vm ${IPA}
sleep 1
ipa_ip=$(getip_vm ${IPA})
ssh -oStrictHostKeyChecking=no -i ${USERNAME}.key ${USERNAME}@${ipa_ip} "echo ${IPA} > /etc/hostname"
ssh -oStrictHostKeyChecking=no -i ${USERNAME}.key ${USERNAME}@${ipa_ip} "sudo apt-get -y install wget"
ssh -oStrictHostKeyChecking=no -i ${USERNAME}.key ${USERNAME}@${ipa_ip} "wget --no-check-certificate -q https://raw.githubusercontent.com/hillar/detektiven/master/freeipa/install-freeipa.bash"
ssh -oStrictHostKeyChecking=no -i ${USERNAME}.key ${USERNAME}@${ipa_ip} "sudo bash -x /home/${USERNAME}/install-freeipa.bash ${ipa_ip}"
stop_vm ${IPA}
start_vm ${IPA}
ipa_ip=$(getip_vm ${IPA})
ssh -oStrictHostKeyChecking=no -i ${USERNAME}.key ${USERNAME}@${ipa_ip} "netstat -ntple"
curl ${ipa_ip}

TIKA='tika'
[ $(vm_exists ${TIKA}) = '0' ] || virt-clone  -o ${FB} -n ${TIKA} --auto-clone

start_vm ${TIKA}
tika_ip=$(getip_vm ${TIKA})
ssh -oStrictHostKeyChecking=no -i ${USERNAME}.key ${USERNAME}@${ipa_ip} "echo ${TIKA} > /etc/hostname"
ssh -oStrictHostKeyChecking=no -i ${USERNAME}.key ${USERNAME}@${tika_ip} "sudo apt-get -y install wget"
ssh -oStrictHostKeyChecking=no -i ${USERNAME}.key ${USERNAME}@${tika_ip} "wget --no-check-certificate -q https://raw.githubusercontent.com/hillar/detektiven/master/stuff/txt/osse/tika/install-tika.bash"
ssh -oStrictHostKeyChecking=no -i ${USERNAME}.key ${USERNAME}@${tika_ip} "sudo bash -x /home/${USERNAME}/install-tika.bash ${tika_ip}"
stop_vm ${IPA}
start_vm ${IPA}
tika_ip=$(getip_vm ${TIKA})
ssh -oStrictHostKeyChecking=no -i ${USERNAME}.key ${USERNAME}@${tika_ip} "netstat -ntple"
curl ${tika_ip}
