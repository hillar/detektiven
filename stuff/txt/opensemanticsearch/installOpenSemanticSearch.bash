#!/bin/bash

#
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

#https://www.opensemanticsearch.org/download/open-semantic-search_17.11.17.deb
OSSVERSION="17.12.01"

echo "$(date) preparing system .."
echo 'Acquire::ForceIPv4 "true";' | sudo tee /etc/apt/apt.conf.d/99force-ipv4
export DEBIAN_FRONTEND=noninteractive
apt-get update >> /vagrant/provision.log 2>&1
apt-get -y upgrade >> /vagrant/provision.log 2>&1

cd /vagrant/
[ -f open-semantic-search_$OSSVERSION.deb ] || wget -q https://www.opensemanticsearch.org/download/open-semantic-search_$OSSVERSION.deb
#echo "$(date) installing depes .."
# see https://raw.githubusercontent.com/opensemanticsearch/open-semantic-search/master/build/deb/stable/DEBIAN/control
apt-get -y install tesseract-ocr scantailor >> /vagrant/provision.log 2>&1
#apt-get -y install default-jre-headless apache2 libapache2-mod-php php php-bcmath libapache2-mod-wsgi-py3 python3-django python3-rdflib python3-pysolr python3-dateutil python3-lxml python3-feedparser poppler-util pst-utils daemon python3-pyinotify python3-celery python3-nltk >> /vagrant/provision.log 2>&1
echo "$(date) INFO dpkg -i open-semantic-search_$OSSVERSION.deb" 
# hack to fix solr install hunging here ;(
# see https://github.com/opensemanticsearch/solr.deb/issues/1
export SYSTEMD_PAGER=''
dpkg -i open-semantic-search_$OSSVERSION.deb
echo "$(date) INFO apt-get -y -f install"
apt-get -y -f install
echo 'SOLR_HOST="0.0.0.0"' >>  /etc/default/solr.in.sh
service solr restart
#sleep 2
#echo "$(date) indexing sample documents .."
opensemanticsearch-index-dir /vagrant/sampledocs/

echo "$(date) installing nodejs"
curl -sL https://deb.nodesource.com/setup_8.x | sudo -E bash - >> /vagrant/provision.log 2>&1
sudo apt-get install -y nodejs >> /vagrant/provision.log 2>&1

echo "$(date) installing solr-security-proxy"
cd /opt
mkdir solr-security-proxy
cd solr-security-proxy
echo '{}' > package.json
npm install solr-security-proxy >> /vagrant/provision.log 2>&1
mkdir bin
ln -s $(npm bin)/solr-security-proxy /opt/solr-security-proxy/bin/solr-security-proxy
mkdir -p /var/log/solr-security-proxy
cat > /lib/systemd/system/solr-security-proxy.service <<EOF
[Unit]
Description=solr-security-proxy
After=network.target
[Service]
Type=simple
Restart=on-failure
StandardOutput=tty
ExecStart=/bin/sh -c '/usr/bin/node /opt/solr-security-proxy/bin/solr-security-proxy --port 9983 --backendHost 127.0.0.1 --backendPort 8983 --validPaths /solr/core1/select >> /var/log/solr-security-proxy/proxy.log 2>&1'
WorkingDirectory=/opt/solr-security-proxy
[Install]
WantedBy=multi-user.target
EOF
systemctl enable solr-security-proxy.service
systemctl start solr-security-proxy.service
