#!/bin/bash
#
# install OSSE + TIKA + SOLR + ETL(python)
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
export LC_ALL=C
echo 'Acquire::ForceIPv4 "true";' > /etc/apt/apt.conf.d/99force-ipv4
export DEBIAN_FRONTEND=noninteractive

echo "$(date) installing java"
java=$(java -version 2>&1 | awk -F '"' '/version/ {print $2}')
if [ "$java" != "" ]; then
  echo "java ver $java exists"
else
  add-apt-repository ppa:webupd8team/java >> /vagrant/provision.log 2>&1
  apt-get update >> /vagrant/provision.log 2>&1
  echo "oracle-java8-installer shared/accepted-oracle-license-v1-1 select true" | sudo debconf-set-selections
  apt-get -y install oracle-java8-installer >> /vagrant/provision.log 2>&1
  java -version
fi

if [ -f "./tika/install-tika.bash" ];
then
    bash ./tika/install-tika.bash
else
  bash /vagrant/tika/install-tika.bash
fi
