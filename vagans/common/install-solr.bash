#!/usr/bin/env bash
#
# install SOLR
#
# enviroment variables /etc/default/SOLR
# start script /opt/SOLR/bin/start-SOLR.bash
# systemctl service SOLR.service
#

log() { echo "$(date) $0: $*"; }
die() { log ": $*" >&2; exit 1; }

[ "$EUID" -ne 0 ] && die "Please run as root"

HOST='0.0.0.0'
[ -z $1 ] || HOST=$1
PORT='8983'
[ -z $2 ] || PORT=$2
ok=$(curl -s http://${HOST}:${PORT}/solr/|wc -l)
[ $ok -gt 0 ] && die "port taken ${HOST}:${PORT}"
SOLR='solr'
VER='7.3.0'
MEM='512m'
DEFAULT="solrdefalutcore"

SOLR_USER=$SOLR
SOLR_GROUP=$SOLR
SOLR_DIR="/opt/$SOLR"
LOG_DIR="/var/log/$SOLR"
DATA_DIR="/var/data/$SOLR"

#stupid systemclt ...
export SYSTEMD_PAGER=''
export LC_ALL=C

java=$(java -version 2>&1 | awk -F '"' '/version/ {print $2}')
if [ "$java" != "" ]; then
  echo "$(date) java ver $java "
else
  echo "no java"
  exit 1
fi

mkdir -p "$SOLR_DIR"
mkdir -p "$DATA_DIR"
SOLR_UID="$PORT"
SOLR_GID="$PORT"

groupadd -r --gid $SOLR_GID $SOLR_GROUP
useradd -r --uid $SOLR_UID --gid $SOLR_GID $SOLR_USER

cd /tmp
solrurl="http://www-us.apache.org/dist/lucene/solr/${VER}/solr-${VER}.tgz"
[ -f "solr-${VER}.tgz" ] || wget -q ${solrurl}
[ -f "solr-${VER}.tgz" ] || die "failed to get solr from ${solrurl}"
cd "$SOLR_DIR"
tar -C "$SOLR_DIR" --extract --file /tmp/solr-${VER}.tgz --strip-components=1
[ $? -eq 0 ] || die "failed to untar /tmp/solr-${VER}.tgz"

# server/solr/configsets/_default/conf/managed-schema
#     <!-- This can be enabled, in case the client does not know what fields may be searched. It isn't enabled by default
#         because it's very expensive to index everything twice. -->
#    <!-- <copyField source="*" dest="_text_"/> -->

sed -i -e 's,<!-- <copyField source="\*" dest="_text_"\/> -->,<copyField source="*" dest="_text_"/>\n<dynamicField name="*" type="text_general" indexed="true" stored="true" multiValued="true"/>,g' server/solr/configsets/_default/conf/managed-schema

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
  $SOLR_DIR/bin/solr create -c $DEFAULT
  sleep 1
  curl -s 'http://localhost:8983/solr/admin/cores?action=STATUS'
  $SOLR_DIR/bin/solr stop -q
EOF

# systemd stuff ...
cat > /etc/default/solr <<EOF
# ! please see /etc/systemd/system/solr.service.d/default.conf
EOF

mkdir -p /etc/systemd/system/solr.service.d
cat > /etc/systemd/system/solr.service.d/default.conf <<EOF
[Service]
Environment='SOLR_HOST=$HOST'
Environment='SOLR_PORT=$PORT'
# Sets the min (-Xms) and max (-Xmx) heap size for the JVM
Environment='SOLR_MEM=$MEM'
# Sets the solr.data.home system property, where Solr will store data (index)
Environment='SOLR_DATA_DIR=$DATA_DIR'
# links log directory to /var/log
Environment='SOLR_LOG_DIR=$LOG_DIR'
EOF

cat > /etc/systemd/system/solr.service <<EOF
[Unit]
Description=Apache Solr Server
Requires=network.target
After=network.target
[Service]
PIDFile=$SOLR_DIR/bin/solr-$PORT.pid
User=$SOLR_USER
Group=$SOLR_GROUP
EnvironmentFile=-/etc/default/solr
ExecStart=$SOLR_DIR/bin/solr start -h \${SOLR_HOST} -p \${SOLR_PORT} -m \${SOLR_MEM} -t \${SOLR_DATA_DIR}
ExecStop=$SOLR_DIR/bin/solr stop
Type=simple
[Install]
WantedBy=multi-user.target
EOF
systemctl daemon-reload
systemctl enable solr.service
systemctl start solr.service
sleep 1
ok=$(curl -s http://${HOST}:${PORT}/solr/|wc -l)
[ $ok -gt 210 ] || die "not solr admin panel  http://${HOST}:${PORT}/solr/"


# java -server -Xms512m -Xmx512m -XX:NewRatio=3 -XX:SurvivorRatio=4 -XX:TargetSurvivorRatio=90 -XX:MaxTenuringThreshold=8 -XX:+UseConcMarkSweepGC -XX:+UseParNewGC -XX:ConcGCThreads=4 -XX:ParallelGCThreads=4 -XX:+CMSScavengeBeforeRemark -XX:PretenureSizeThreshold=64m -XX:+UseCMSInitiatingOccupancyOnly -XX:CMSInitiatingOccupancyFraction=50 -XX:CMSMaxAbortablePrecleanTime=6000 -XX:+CMSParallelRemarkEnabled -XX:+ParallelRefProcEnabled -XX:-OmitStackTraceInFastThrow -verbose:gc -XX:+PrintHeapAtGC -XX:+PrintGCDetails -XX:+PrintGCDateStamps -XX:+PrintGCTimeStamps -XX:+PrintTenuringDistribution -XX:+PrintGCApplicationStoppedTime -Xloggc:/opt/solr/server/logs/solr_gc.log -XX:+UseGCLogFileRotation -XX:NumberOfGCLogFiles=9 -XX:GCLogFileSize=20M -Dsolr.log.dir=/opt/solr/server/logs -Djetty.port=8983 -DSTOP.PORT=7983 -DSTOP.KEY=solrrocks -Dhost=127.0.0.1 -Duser.timezone=UTC -Djetty.home=/opt/solr/server -Dsolr.solr.home=/opt/solr/server/solr -Dsolr.data.home=/var/data/solr -Dsolr.install.dir=/opt/solr -Dsolr.default.confdir=/opt/solr/server/solr/configsets/_default/conf -Xss256k -Dsolr.jetty.https.port=8983 -Dsolr.log.muteconsole -XX:OnOutOfMemoryError=/opt/solr/bin/oom_solr.sh 8983 /opt/solr/server/logs -jar start.jar --module=http

#java -jar /opt/solr/server/start.jar STOP.PORT=7983 STOP.KEY=solrrocks
log "installed solr to $SOLR_DIR"
log "solr server will run on $HOST:$PORT "
log "data dir is $DATA_DIR"
log "log dir is  $LOG_DIR"
log "done $0"
