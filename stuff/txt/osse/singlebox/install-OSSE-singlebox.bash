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
mkdir /provision
cd /provision/
wget -q https://github.com/hillar/detektiven/archive/master.tar.gz
tar -xzf master.tar.gz
rm master.tar.gz
bash /provision/detektiven-master/stuff/txt/osse/tika/install-tika.bash
bash /provision/detektiven-master/stuff/txt/osse/solr/install-solr.bash
bash /provision/detektiven-master/stuff/txt/osse/elasticsearch/install-elastic.bash
bash /provision/detektiven-master/stuff/txt/osse/etl/install-etl.bash
bash /provision/detektiven-master/stuff/txt/osse/server/install-osse.bash 
bash /provision/detektiven-master/stuff/txt/osse/server/install-osse.bash
