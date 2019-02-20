#!/usr/bin/env bash
# some virsh und virt-* helpers

export LC_ALL=C

log() { echo "$(date) $0: $*"; }
die() { log "$*" >&2; exit 1; }

vm_exists() {
  virsh domstate $1 >/dev/null 2>&1
  return $?
}

# destroy and undefine and delete storage
vm_delete() {
  vm_exists $1 || log "!? not exists $1"
  vm_exists $1 && log "deleting $1"
  vm_stop $1 || die "can not delete $1"
  virsh undefine $1 --managed-save --snapshots-metadata --nvram --remove-all-storage >/dev/null 2>&1
  [ $? -eq 0 ] || die "failed to delete $1"
  log "deleted $1"
}

vm_running() {
  [ "$(virsh domstate $1 2>/dev/null)" == "running" ] || return 1
}

# force if shutdown not in 60 seconds
vm_stop(){
  vm_running $1 || log "!? not running $1"
  vm_running $1 || return 0
  virsh shutdown $1 >/dev/null 2>&1
  counter=0
  vm_running $1
  last=$?
  while  [ $last -eq 0 -a $counter -lt 20 ]; do
    sleep 3
    let counter++
    vm_running $1
    last=$?
  done
  if [ $counter -eq 20 ]; then
    log "forcing shutdown $1"
     virsh destroy $1 >/dev/null 2>&1
     [ $? -eq 0 ] || die "failed to stop $1"
  else
    log "shutdown ok $1"
  fi
}

vm_start() {
  vm_running $1 && log "!? already running $1"
  vm_running $1 && return 0
  virsh start $1 >/dev/null 2>&1
  counter=0
  vm_running $1
  last=$?
  while [ ! $last -eq 0 -a $counter -lt 10 ]; do
    sleep 1
    let counter++
    vm_running $1
    last=$?
  done
  if [ $counter -eq 10 ]; then
     die "failed to start $1"
  else
     log "started $1"
     return 0
  fi
}

vm_reboot() {
  log "rebooting $1"
  vm_stop $1
  vm_start $1
}

vm_getip(){
  vm_running $1 || die "not running $1"
  last=$(virsh domifaddr $1|wc -l)
  counter=0
  while  [ $last -lt 4 -a $counter -lt 10 ]; do
    let counter++
    sleep 3
    last=$(virsh domifaddr $1|wc -l)
  done
  ip=$(virsh domifaddr $1 | grep ipv4 | tail -1| awk '{print $4}'| cut -f1 -d"/" | grep -o '[0-9]\{1,3\}\.[0-9]\{1,3\}\.[0-9]\{1,3\}\.[0-9]\{1,3\}')
  ok=$(echo $ip | grep -o '[0-9]\{1,3\}\.[0-9]\{1,3\}\.[0-9]\{1,3\}\.[0-9]\{1,3\}'| wc -l)
  if [ $ok -eq 1 ]; then
      echo $ip
      return 0
  else
      ping -c 2 $1 &> /dev/null
      maca=$(virsh domiflist $1 | grep bridge | head -1 | awk '{print $5}')
      ip=$(arp | grep "${maca}" | awk '{print $1}')
      ok2=$(echo $ip | grep -o '[0-9]\{1,3\}\.[0-9]\{1,3\}\.[0-9]\{1,3\}\.[0-9]\{1,3\}'| wc -l)
      #echo "$maca $ip $ok2"
      if [ $ok2 -eq 1 ]; then
        echo $ip
        return 0
      else
        return 1
      fi
  fi
}

vm_waitforssh(){
  [ -z $3 ] && die "no user"
  [ -z $2 ] && die "no key file"
  [ -z $1 ] && die "no vm name"
  ip=$(vm_getip $1)
  [ $? -ne 0 ] && die "no ip for $1"
  counter=0
  ssh-keygen -f "~/.ssh/known_hosts" -R $ip > /dev/null 2>&1
  ssh-keygen -f "/root/.ssh/known_hosts" -R $ip > /dev/null 2>&1
  h=$(ssh -oStrictHostKeyChecking=no -i $2 $3@${ip} 'hostname') > /dev/null 2>&1
  while  [ $? -ne 0 -a $counter -lt 30 ]; do
    sleep 2
    let counter++
    h=$(ssh -oStrictHostKeyChecking=no -i $2 $3@${ip} 'hostname') > /dev/null 2>&1
  done
  if [ $counter -eq 30 ]; then
     die "no ssh for $1"
  else
    [ "$h" == "$1" ] && log "ssh ok $1 ( ssh -i $2 $3@${ip} )"
    [ "$h" == "$1" ] || log "WARNING hostname $h does not match vm name $1"
  fi
}

vm_ssh() {
  [ -z $4 ] && die "no command to run"
  [ -z $3 ] && die "no user"
  [ -z $2 ] && die "no key file"
  [ -z $1 ] && die "no vm name"
  ip=$(vm_getip $1)
  [ $? -ne 0 ] && die "no ip for $1"
  ssh -oStrictHostKeyChecking=no -i $2 $3@${ip} "$4"
}

vm_getimagefile() {
  vm_exists $1 || die "vm not exists $1"
  imagefile=$(virsh dumpxml $1 | grep $1 | grep file | cut -f2 -d"'")
  [ -f $imagefile ] || die "file not exists $1 $imagefile"
  echo "$imagefile"
}

# vm_clone PARENT CHILD
#
# will not clone if
# child name resolves
# child vm exists
#
# sets name to /etc/hostname
vm_clone(){

  [ -z $1 ] && die 'no parent name'
  PARENT=$1
  vm_exists $1 || die "parent ${PARENT} not exists"
  vm_running $1 && die "parent ${PARENT} running"

  [ -z $2 ] && die 'no child name'
  CHILD=$2
  host ${CHILD} >/dev/null 2>&1
  [ $? -eq 0 ] && die 'child name taken'
  virsh domstate ${CHILD} >/dev/null 2>&1
  [ $? -eq 0 ] && die "child ${CHILD} exists"
  [ -z $3 ] || USER=$3
  [ -z ${USER} ] && USER='root'
  # file or not
  imagefile=$(virsh domblklist ${PARENT} | grep vda | awk '{print $2}')
  domblk=$(virsh vol-info ${imagefile}| grep Type:| awk '{print $2}')
  if [ "${domblk}" == "file" ]; then
    virt-clone -o ${PARENT} -n ${CHILD} --reflink --auto-clone >/dev/null 2>&1
    [ $? -eq 0 ] || virt-clone -o ${PARENT} -n ${CHILD} --auto-clone >/dev/null 2>&1
    [ $? -eq 0 ] || die "virt-clone error ${PARENT} -> ${CHILD}"

    imagefile=$(virsh domblklist ${CHILD} | grep vda | awk '{print $2}')

    # TODO tmp dir name
    mkdir /tmp/${CHILD}
    guestmount -a ${imagefile} -i /tmp/${CHILD}
    [ $? -eq 0 ] || die "guestmount error, ${imagefile}"
    echo ${CHILD} > /tmp/${CHILD}/etc/hostname
    echo "$(date) cloned from ${PARENT} got name ${CHILD}" >> /tmp/${CHILD}/etc/birth.certificate
    if [ ! -z $USER ]; then
      path='ERROR'
      if [ "$USER" == "root" ]; then
        cat ${USER}.key.pub > /tmp/${CHILD}/root/.ssh/authorized_keys
        path='/root/.ssh/authorized_keys'
      else
        if [ -d /tmp/${CHILD}/home/${USER} ]; then
          [ -d /tmp/${CHILD}/home/${USER}/.ssh ] || mkdir /tmp/${CHILD}/home/${USER}/.ssh
          cat ${USER}.key.pub > /tmp/${CHILD}/home/${USER}/.ssh/authorized_keys
          path="/home/${USER}/.ssh/authorized_keys"
        else
          die "user ${USER} not exists in ${PARENT}"
        fi
      fi
      echo "$(date) user ${USER} key set ${path}" >> /tmp/${CHILD}/etc/birth.certificate
    fi
    umount /tmp/${CHILD}
    rmdir /tmp/${CHILD}
    log "cloned ${PARENT} -> ${CHILD}"
  else
    POOL=$(virsh domblklist ${PARENT} | grep vda | awk '{print $2}'| cut -f1 -d/)
    [ -z ${POOL} ] && die "no pool name"
    virsh pool-info ${POOL} || die "no pool ${POOL}"
    virsh vol-info --pool ${POOL} ${CHILD}-vda && die "vol already exists ${POOL} ${CHILD}-vda"
    # clone vol
    virsh vol-clone --pool ${POOL} --vol ${PARENT}-vda --newname ${CHILD}-vda || die "failed to clone disk ${POOL}/${PARENT}-vda -> ${POOL}/${CHILD}-vda"
    # dump the xml
    virsh dumpxml ${PARENT} > /tmp/${CHILD}.xml
    # things need to be removed
    # <uuid>b4baafde-d397-4e4a-8022-7a9e3911d15c</uuid>
    # ! do not remove <secret type='ceph' uuid='
    sed -i '/<uuid.*/{s///;:a;n;ba}' /tmp/${CHILD}.xml
    # <mac address='52:54:00:94:fe:51'/>
    sed -i '/mac address/d' /tmp/${CHILD}.xml
    # and actually rename the vm and volume
    # <name>fedora-dummy</name>
    # <source protocol='rbd' name='vmlive0/clone1-vda'>
    sed -i 's/'${PARENT}'/'${CHILD}'/' /tmp/${CHILD}.xml
    # create the CHILD vm
    virsh define /tmp/${CHILD}.xml || die "Failed to define domain ${CHILD}"
    # start and ssh in to change hostname
    vm_start ${CHILD} || die "failed to start ${CHILD}"
    ip=$(vm_getip ${CHILD}) || die "${CHILD} failed to get ip"
    vm_waitforssh ${CHILD} ${USER}.key ${USER} || vm_waitforssh ${CHILD} ${USER}.key ${USER} || die " ${CHILD} failed to ssh in"
    ssh -i ${USER}.key ${USER}@${ip} "hostnamectl set-hostname ${CHILD}" || die "${CHILD} failed to set hostname "
    ssh -i ${USER}.key ${USER}@${ip} "hostname"
    log "done with ${PARENT} -> ${CHILD} (${ip})"
  fi

}
