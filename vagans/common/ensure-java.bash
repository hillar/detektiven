#!/usr/bin/env bash
#
# install java
#

log() { echo "$(date) $0: $*"; }
die() { log ": $*" >&2; exit 1; }

[ "$EUID" -ne 0 ] && die "Please run as root"

java -version > /dev/null 2&>1
if [ $? -eq 0 ]; then
  log "java exists $(java -version) "
else
  log "installing java"
  apt --help > /dev/null 2>&1
  if [ $? -eq 0 ]; then
  apt -y install software-properties-common >>  /tmp/provision.log 2>&1
  add-apt-repository ppa:webupd8team/java >>  /tmp/provision.log 2>&1
  apt-get update >>  /tmp/provision.log 2>&1
  echo "oracle-java8-installer shared/accepted-oracle-license-v1-1 select true" | sudo debconf-set-selections
  apt-get -y install oracle-java8-installer >>  /tmp/provision.log 2>&1
  fi
  dnf --help > /dev/null 2>&1
  if [ $? -eq 0 ]; then
    dnf -4 -q -y install java-1.8.0-openjdk wget tar lsof >>  /tmp/provision.log 2>&1
  fi
  java -version > /dev/null 2&>1
  [ $? -eq 0 ] || die 'failed to install java'
  log "installed java $(java -version) "
fi
