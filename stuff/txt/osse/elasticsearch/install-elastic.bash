#!/bin/bash
#
# install elastic
#


echo "$(date) starting $0"

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
#stupid systemclt ...
export SYSTEMD_PAGER=''
export LC_ALL=C

ELA='elastic'
VER='6.2.2'
HOST='127.0.0.1'
PORT='9200'
MEM='512m'


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

[ -f "elasticsearch-${VER}.deb" ] || wget -q https://artifacts.elastic.co/downloads/elasticsearch/elasticsearch-${VER}.deb
dpkg -i elasticsearch-${VER}.deb >> /vagrant/provision.log 2>&1
#TODO set host port mem
systemctl daemon-reload
systemctl enable elasticsearch.service >> /vagrant/provision.log 2>&1
echo "installed elasticsearch from default deb package"
echo "elastic server will run on $HOST:$PORT "
echo "start elastic server with 'systemctl start elasticsearch.service'"
echo "$(date) done $0"
