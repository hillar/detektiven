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

IP=$1
[ -z $1 ] && IP="192.168.11.2"
IPA=$2
[ -z $2 ] && IPA="192.168.10.2"

[ -d "/vagrant" ] || mkdir /vagrant
export LC_ALL=C
[ -d /provision ] || mkdir /provision
cd /provision/
[ -f master.tar.gz ] && rm master.tar.gz
wget -q https://github.com/hillar/detektiven/archive/master.tar.gz
tar -xzf master.tar.gz
rm master.tar.gz
bash /provision/detektiven-master/stuff/txt/osse/tika/install-tika.bash
systemctl start tika.service
bash /provision/detektiven-master/stuff/txt/osse/solr/install-solr.bash
systemctl start solr.service
bash /provision/detektiven-master/stuff/txt/osse/elasticsearch/install-elastic.bash
systemctl start elasticsearch.service
bash /provision/detektiven-master/stuff/txt/osse/etl/install-etl.bash
bash /provision/detektiven-master/stuff/txt/osse/fileserver/install-fileserver.bash
systemctl start osse-fileserver-news-monitor.service
systemctl start systemctl start osse-fileserver.service
bash /provision/detektiven-master/stuff/txt/osse/server/install-osse.bash $IP $IPA
systemctl start osse-server.service

touch /tmp/empty.file
f=/tmp/empty.file
curl -s -XPOST -F "data=@$f" -F "tags=TEST" -H "Content-Type: multipart/form-data" -uuploadonly:uploadonly "$IP:9983/files"
sleep 3
etl-file /tmp/empty.file
