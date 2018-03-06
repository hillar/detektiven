#!/bin/bash
#
# install OSSE
#
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

export SYSTEMD_PAGER=''
export LC_ALL=C
export DEBIAN_FRONTEND=noninteractive

node=$(node -v)
if [ "$node" != "" ]; then
  echo "$(date) node ver $node"
else
  echo "$(date) installing node"
  curl -sL https://deb.nodesource.com/setup_9.x | sudo -E bash - >> /vagrant/provision.log 2>&1
  # apt-get update >> /vagrant/provision.log 2>&1
  apt-get -y upgrade >> /vagrant/provision.log 2>&1
  apt-get -y install nodejs
fi
