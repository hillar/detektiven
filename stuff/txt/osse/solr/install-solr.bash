#!/bin/bash
#
# install SOLR
#
# enviroment variables /etc/default/SOLR
# start script /opt/SOLR/bin/start-SOLR.bash
# systemctl service SOLR.service
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

export LC_ALL=C
#stupid systemclt ...
export SYSTEMD_PAGER=''

SOLR='solr'
VER='7.2.1'
MEM='512m'


SOLR_USER=$SOLR
SOLR_GROUP=$SOLR
SOLR_DIR="/opt/$SOLR"
LOG_DIR="/var/log/$SOLR"
DATA_DIR="/var/data/$SOLR"

mkdir -p "$SOLR_DIR"
mkdir -p "$DATA_DIR"
SOLR_UID="8983"
SOLR_GID="8983"
DEFAULT="solrdefalutcore"
groupadd -r --gid $SOLR_GID $SOLR_GROUP
useradd -r --uid $SOLR_UID --gid $SOLR_GID $SOLR_USER
#addgroup --system "$SOLR_GROUP" --quiet
#adduser --system --home $SOLR_DIR --no-create-home --ingroup $SOLR_GROUP --disabled-password --shell /bin/false "$SOLR_USER"

cd /tmp
[ -f "solr-${VER}.tgz" ] || wget -q http://www-us.apache.org/dist/lucene/solr/7.2.1/solr-${VER}.tgz
cd "$SOLR_DIR"
tar -C "$SOLR_DIR" --extract --file /tmp/solr-${VER}.tgz --strip-components=1

mkdir -p "$SOLR_DIR/server/logs"
ln -s  "$SOLR_DIR/server/logs" "$LOG_DIR"
chown -R $SOLR_USER:$SOLR_GROUP "$SOLR_DIR"
chown -R $SOLR_USER:$SOLR_GROUP "$DATA_DIR"
chown -R $SOLR_USER:$SOLR_GROUP "$LOG_DIR"

# run as solr to create default core
sudo -u "$SOLR_USER" sh -s "$@" <<EOF
  whoami
  $SOLR_DIR/bin/solr start -t $DATA_DIR -q
  sleep 1
  $SOLR_DIR/bin/solr create -c $DEFAULT -q
  sleep 1
  curl 'http://localhost:8983/solr/admin/cores?action=STATUS'
  $SOLR_DIR/bin/solr stop -q
EOF

# systemd stuff ...
cat > /etc/default/solr <<EOF
# ! please see /etc/systemd/system/solr.service.d/default.conf
EOF

mkdir -p /etc/systemd/system/solr.service.d
cat > /etc/systemd/system/solr.service.d/default.conf <<EOF
[Service]
# Sets the min (-Xms) and max (-Xmx) heap size for the JVM
Environment='SOLR_MEM=$MEM'
# Sets the solr.data.home system property, where Solr will store data (index)
Environment='SOLR_DATA_DIR=$DATA_DIR'
# SOLR logs directory
Environment='SOLR_LOG_DIR=''$LOG_DIR'
Environment='SOLR_HOST=127.0.0.1'
Environment='SOLR_PORT=8983'
EOF

cat > /etc/systemd/system/solr.service <<EOF
[Unit]
Description=Apache Solr Server
Requires=network.target
After=network.target
[Service]
PIDFile=$SOLR_DIR/bin/solr-$SOLR_PORT.pid
User=$SOLR_USER
Group=$SOLR_GROUP
EnvironmentFile=-/etc/default/solr
ExecStart=$SOLR_DIR/bin/solr start -h \${SOLR_HOST} -p \${SOLR_PORT} -m \${SOLR_MEM} -t \${SOLR_DATA_DIR} -V
ExecStop=$SOLR_DIR/bin/solr stop
Type=simple
[Install]
WantedBy=multi-user.target
EOF
systemctl daemon-reload
systemctl enable solr.service
systemctl start solr.service
systemctl status solr.service
ps aux | grep java
sleep 5
systemctl status solr.service
ps aux | grep java
#tail -100 /var/log/syslog
#should be exit because 'Found 0 core definitions underneath /opt/solr/server/solr'

echo "$(date) done $0"
