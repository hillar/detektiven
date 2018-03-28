#!/usr/bin/env bash

# Check whether a named virtual machine exists.
#
# Arguments:
#   1: virtual machine name given by virsh
#
# echos:
#   0 if virtual machine exists
#   1 if virtual machine does not exist
vm_exists() {
  virsh domstate $1 >/dev/null 2>&1
  echo $?
}

# Check whether a named virtual machine is running.
#
# Arguments:
#   1: virtual machine name given by virsh
#
# echos:
#   0 if virtual machine is running
#   1 if virtual machine is not running or does not exist
vm_is_running() {
  if [ "$(virsh domstate $1 2>/dev/null)" == "running" ]; then
    echo 0
  else
    echo 1
    return 1
  fi
}


# Start a named virtual machine and wait for running.
#
# Arguments:
#   1: virtual machine name given by virsh
start_vm() {
  if [ ! $(vm_is_running $1) -eq 0 ]; then
    virsh start $1
  fi
  counter=0
  while [ ! $(vm_is_running $1) -eq 0 -a $counter -lt 10 ]; do
    sleep 1
    let counter++
  done
  if [ $counter -eq 10 ]; then
     return 1
  else
     return 0
  fi
}

# Shut down a virtual machine through the normal shutdown signal. This
# results in a clean shutdown via the guest operating system.
#
# Arguments:
#   1: virtual machine name given by virsh
shutdown_vm() {
  if [ $(vm_is_running $1) -eq 0 ]; then
    virsh shutdown $1
  fi
}

# Forcibly stop a virtual machine, even if it is not responding.
#
# Arguments:
#   1: virtual machine name given by virsh
force_stop_vm() {
  if [ $(vm_is_running $1) -eq 0 ]; then
    virsh destroy $1
  fi
}

# Shut down a virtual machine through the normal shutdown signal.
# wait for 10 * 2 seconds, then forcibly stop a virtual machine
#
# Arguments:
#   1: virtual machine name given by virsh
stop_vm(){
  shutdown_vm $1
  counter=0
  while  [ $(vm_is_running $1) -eq 0 -a $counter -lt 10 ]; do
    sleep 3
    let counter++
  done
  if [ $counter -eq 10 ]; then
     force_stop_vm $1
  fi
}

# Sleep until the given virtual machine has ip address.
# echos ip or returns 1 if timed out on 10 * 2 seconds.
#
# Arguments:
#   1: virtual machine name given by virsh

getip_vm(){
  if [ $(vm_is_running $1) -eq 0 ]; then
    last=$(virsh domifaddr $1|wc -l)
    counter=0
    while  [ $last -lt 4 -a $counter -lt 10 ]; do
      sleep 2
      last=$(virsh domifaddr $1|wc -l)
      let counter++
    done
    if [ $counter -eq 10 ]; then
       return 1
    else
      echo $(virsh domifaddr $1 | grep ipv4 | head -1| awk '{print $4}'| cut -f1 -d"/")
    fi
  else
    return 1
  fi
}

# Get image file full path
#
# Arguments:
#   1: virtual machine name given by virsh
getfile_vm(){
  echo $(virsh dumpxml $1 | grep $1 | grep file | cut -f2 -d"'")
}

# Delete a virtual machine, all of its metadata, snapshots and storage.
# This should remove all traces of the VM.
#
# Arguments:
#   1: virtual machine name given by virsh
delete_vm() {
  force_stop_vm $1
  virsh undefine $1 --managed-save --snapshots-metadata --nvram --remove-all-storage
}

compress_vm(){
  NAME=$1
  [ $(vm_is_running ${NAME}) = '0' ] && stop_vm ${NAME}
  imagefile=$(getfile_vm ${NAME})
  mv $imagefile $imagefile.backup
  qemu-img convert -O qcow2 -c $imagefile.backup $imagefile
  rm $imagefile.backup
}
