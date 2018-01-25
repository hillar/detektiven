#!/bin/bash
#
# TIKA SOLR und ETL in single box
# + minimal web UI for upload and search (depends on freeipa)
#
# see https://opensemanticsearch.org/etl


XENIAL=$(lsb_release -c | cut -f2)
if [ "$XENIAL" != "xenial" ]; then
    echo "sorry, tested only with xenial ;("; 1>&2
    exit1;
fi

if [ "$(id -u)" != "0" ]; then
   echo "ERROR - This script must be run as root" 1>&2
   exit 1
fi

# see https://opensemanticsearch.org/download/
# https://www.opensemanticsearch.org/download/solr.deb_17.12.08.deb
# https://www.opensemanticsearch.org/download/tika-server.deb_17.06.23.deb
# https://www.opensemanticsearch.org/download/open-semantic-etl_17.12.08.deb
SOLRVERSION="17.12.08"
TIKAVERSION="17.06.23"
ETLVERSION="17.12.08"
SOLR="solr.deb_$SOLRVERSION.deb"
TIKA="tika-server.deb_$TIKAVERSION.deb"
ETL="open-semantic-etl_$ETLVERSION.deb"

echo "$(date) preparing system .."
echo 'Acquire::ForceIPv4 "true";' | sudo tee /etc/apt/apt.conf.d/99force-ipv4
export DEBIAN_FRONTEND=noninteractive
echo "$(date) adding  nodejs repo .."
curl -sL https://deb.nodesource.com/setup_9.x | sudo -E bash - >> /vagrant/provision.log 2>&1
# apt-get update >> /vagrant/provision.log 2>&1
apt-get -y upgrade >> /vagrant/provision.log 2>&1
echo "$(date) installing depes .."
apt-get -y install inotify-tools jq nodejs default-jre-headless daemon curl python3-pycurl python3-rdflib file python3-requests python3-pysolr python3-dateutil python3-lxml python3-feedparser poppler-utils pst-utils rabbitmq-server python3-celery python3-pyinotify python3-pip python3-dev build-essential scantailor tesseract-ocr tesseract-ocr-deu tesseract-ocr-est tesseract-ocr-rus tesseract-ocr-eng >> /vagrant/provision.log 2>&1

echo "$(date) installing solr tika und etl .."
cd /vagrant/
[ -f "$SOLR" ] || wget -q https://opensemanticsearch.org/download/$SOLR
dpkg -i "$SOLR" >> /vagrant/provision.log 2>&1
systemctl enable solr.service
[ -f "$TIKA" ] || wget -q https://opensemanticsearch.org/download/$TIKA
dpkg -i "$TIKA" >> /vagrant/provision.log 2>&1
systemctl enable tika.service
[ -f "$ETL" ] || wget -q https://opensemanticsearch.org/download/$ETL
dpkg -i "$ETL" >> /vagrant/provision.log 2>&1

echo "$(date) installing web ui .."
#TODO simply
[ -f master.tar.gz ] || wget -q https://github.com/hillar/detektiven/archive/master.tar.gz
cd /tmp
tar -xzf /vagrant/master.tar.gz
cd /opt
cp -r /tmp/detektiven-master/stuff/txt/opensemanticsearch/oss-mini .
cd oss-mini
chmod +x upload-directory-monitor.bash
chmod +x push2solr4put2archive.bash
chmod +x just-send-mail.bash
cp upload-directory-monitor.defaults /etc/default/upload-directory-monitor
cp upload-directory-monitor.systemd.service /lib/systemd/system/upload-directory-monitor.service
systemctl enable upload-directory-monitor.service

npm install --unsafe-perm >> /vagrant/provision.log 2>&1
mkdir -p /var/spool/oss-mini/upload
cd /tmp/detektiven-master/stuff/txt/opensemanticsearch/solr-buefy/test2
npm install >> /vagrant/provision.log 2>&1
npm run build >> /vagrant/provision.log 2>&1
cd /opt/oss-mini/
cp -r /tmp/detektiven-master/stuff/txt/opensemanticsearch/solr-buefy/test2/dist .
node oss-mini-server.js --help
mkdir  /var/log/oss-mini-server
cp oss-mini-server.systemd.service /lib/systemd/system/oss-mini-server.service
systemctl enable oss-mini-server.service

systemctl start upload-directory-monitor.service
systemctl start oss-mini-server.service
sleep 2
netstat -ntple
curl -s 127.0.0.1:9998/? | wc -l
curl -s 127.0.0.1:8983/solr/core1/select?wt=json | jq .
curl -s 192.168.11.2:9983
