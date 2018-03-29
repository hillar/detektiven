#!/bin/bash
#
# install oracle java
#

XENIAL=$(lsb_release -c | cut -f2)
if [ "$XENIAL" != "xenial" ]; then
    echo "sorry, tested only with xenial ;(";
    exit;
fi

if [ "$(id -u)" != "0" ]; then
   echo "ERROR - This script must be run as root" 1>&2
   exit 1
fi

DEBUGLOG=/tmp/LOG.$0
[ -z $1 ] DEBUGLOG=$1

java=$(java -version 2>&1 | awk -F '"' '/version/ {print $2}')
if [ "$java" != "" ]; then
  echo "$(date) $0 java ver $java "
else
  echo "$(date) $0 installing java"
  apt -y install software-properties-common >> $DEBUGLOG 2>&1
  add-apt-repository ppa:webupd8team/java >> $DEBUGLOG 2>&1
  apt-get update >> $DEBUGLOG 2>&1
  echo "oracle-java8-installer shared/accepted-oracle-license-v1-1 select true" | sudo debconf-set-selections
  apt-get -y install oracle-java8-installer >> $DEBUGLOG 2>&1
  java=$(java -version 2>&1 | awk -F '"' '/version/ {print $2}')
  if [ "$java" != "" ]; then
    echo "$(date) $0 installed java ver $java "
  else
    echo "$(date) $0 java install failed "
    return 1
  fi
fi
