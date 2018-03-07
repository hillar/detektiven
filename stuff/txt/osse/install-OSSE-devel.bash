#!/bin/bash
#
# install OSSE + TIKA + SOLR + fileserver + ETL(python)
# download vagrantfile and this install script
#

XENIAL=$(lsb_release -c | cut -f2)
if [ "$XENIAL" != "xenial" ]; then
    echo "sorry, tested only with xenial ;("; 1>&2
    exit1;
fi

if [ "$(id -u)" != "0" ]; then
   echo "ERROR - This script must be run as root" 1>&2
   exit 1
fi

[ -d "/vagrant" ] || mkdir /vagrant
export LC_ALL=C

export SYSTEMD_PAGER=''
export LC_ALL=C
export DEBIAN_FRONTEND=noninteractive

node=$(nodejs -v)
if [ "$node" != "" ]; then
  echo "$(date) nodejs ver $node"
else
  echo "$(date) installing nodejs"
  curl -sL https://deb.nodesource.com/setup_9.x | sudo -E bash - >> /vagrant/provision.log 2>&1
  # apt-get update >> /vagrant/provision.log 2>&1
  apt-get -y upgrade >> /vagrant/provision.log 2>&1
  apt-get -y install nodejs >> /vagrant/provision.log 2>&1
fi

java=$(java -version 2>&1 | awk -F '"' '/version/ {print $2}')
if [ "$java" != "" ]; then
  echo "$(date) java ver $java "
else
  echo "$(date) installing java"
  add-apt-repository ppa:webupd8team/java >> /vagrant/provision.log 2>&1
  apt-get update >> /vagrant/provision.log 2>&1
  echo "oracle-java8-installer shared/accepted-oracle-license-v1-1 select true" | sudo debconf-set-selections
  apt-get -y install oracle-java8-installer >> /vagrant/provision.log 2>&1
  java -version
fi
