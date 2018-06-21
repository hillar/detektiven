#!/bin/bash
#
# install OSSE
#
#

log() { echo "$(date) $(basename $0): $*"; }
die() { log "$*" >&2; exit 1; }

[ "$(id -u)" != "0" ] && die "user is not 0"
DEBUGDIR='/tmp/install-osse/'
[ -d "${DEBUGDIR}" ] || mkdir /tmp/install-osse || die "can not create ${DEBUGDIR}"
DEBUG="${DEBUGDIR}/debug"
echo "$(date) $0 -----------------" >> ${DEBUG} || die "can not write to ${DEBUG}"
nodejs --version &>> ${DEBUG} || die "no nodejs"
IP=$1
[ -z $1 ] && IP="127.0.0.1"
IPAHOST=$2
[ -z $2 ] && IPAHOST="127.0.0.1"

log "starting with ${IP} ${IPAHOST}"
# TODO look if there is defaults ...
OSSE='osse-server'
OSSE_DIR="/opt/$OSSE"
HOST=$IP
PORT='9983'
MD5FIELDNAME='file_md5_s'
BASE="dc=IDM,dc=ORG,dc=TLD"
IDMSERVER="${IPAHOST}"
READONLY='onlyread'

OSSE_USER=$OSSE
OSSE_GROUP=$OSSE
OSSE_DIR="/opt/$OSSE"
LOG_DIR="/var/log/$OSSE"
DATA_DIR="/var/data/$OSSE"
SESS_DIR="$DATA_DIR/session"
SUBS_DIR="$DATA_DIR/subscritions"
SPOOL_DIR="$DATA_DIR/spool"

export SYSTEMD_PAGER=''
export LC_ALL=C

if [ ! -d /provision/detektiven-master/stuff/txt/osse ]; then
  [ -d /provision ] || mkdir /provision
  cd /provision/
  [ -f master.tar.gz ] && rm master.tar.gz
  wget -q https://github.com/hillar/detektiven/archive/master.tar.gz
  tar -xzf master.tar.gz
  rm master.tar.gz
fi

groupadd --system ${OSSE_GROUP} &>> ${DEBUG}
adduser --system --home $OSSE_DIR --no-create-home --gid $(getent group ${OSSE_GROUP} | cut -d: -f3) --shell /bin/false "$OSSE_USER" &>> ${DEBUG}
getent shadow "$OSSE_USER" &>> ${DEBUG} || die "failed to create user $OSSE_USER $OSSE_GROUP"

mkdir -p "$OSSE_DIR/bin"
mkdir -p "$OSSE_DIR/conf"
mkdir -p "$OSSE_DIR/js"
cd "$OSSE_DIR/js"
cp /provision/detektiven-master/stuff/txt/osse/server/* . &>> ${DEBUG}
#TODO replace this ugly hack with some sane bundler....
mkdir common &>> ${DEBUG}
cd common
grep common ../osse-server.js | grep -v '//'| cut -f2 -d"'"| cut -f3 -d"/"| while read f;
do
  cp /provision/detektiven-master/stuff/txt/osse/common/$f .
done
cd ..
npm install --unsafe-perm &>> ${DEBUG}
npm rebuild --unsafe-perm --update-binary lzma-native &>> ${DEBUG}
cd /provision/detektiven-master/stuff/txt/osse/browser/osse-browser
npm install &>> ${DEBUG}
npm run build &>> ${DEBUG}
mv dist "$OSSE_DIR/js"
cd "$OSSE_DIR/js"
cp dist/static/favicon.ico dist/
mkdir -p $LOG_DIR
mkdir -p $DATA_DIR
mkdir -p $SESS_DIR
mkdir -p $SUBS_DIR
mkdir -p $SPOOL_DIR
node osse-server.js -g > ../conf/config.json.defaults || die "cant not create sample defaults config $(pwd)"
cat > $OSSE_DIR/conf/config.json <<EOF
{
  "portListen": "${PORT}",
  "ipBind": "${HOST}",
  "usersFile": "$DATA_DIR/users/users.json",
  "uploadDirectory": "${SPOOL_DIR}",
  "subscriptionsDirectory": "${SUBS_DIR}",
  "staticDirectory": "$OSSE_DIR/js/dist",
  "smtpfrom": "noreply-osse@localhost",
  "smtphost": "127.0.0.1",
  "smtpport": 25,
  "ipaServer": "${IDMSERVER}",
  "ipaBase": "${BASE}",
  "ipaBindpass": "password",
  "ipaBinduser": "${READONLY}",
  "ipaUsergroup": "osse",
  "ipaUserField": "uid",
  "realm": "osse",
  "reauth": 60000,
  "metaFilename": "meta.json",
  "subscriptionsFilename": "subscriptions.json",
  "etlMapping": "file:///",
  "md5Fieldname": "${MD5FIELDNAME}",
  "uploadFileServer": "127.0.0.1",
  "uploadFileServerProto": "http",
  "filesPort": 8125,
  "uploadUser": "uploadonly",
  "servers": [
    {
      "HR": "hardCodedDefault",
      "type": "solr",
      "proto": "http",
      "host": "localhost",
      "port": 8983,
      "collection": "solrdefalutcore",
      "rotationperiod": "none"
    }
  ]
}
EOF

chown -R $OSSE_USER:$OSSE_GROUP "$OSSE_DIR"
chown $OSSE_USER:$OSSE_GROUP "$LOG_DIR"
chown $OSSE_USER:$OSSE_GROUP "$DATA_DIR"
chown $OSSE_USER:$OSSE_GROUP "$SESS_DIR"
chown $OSSE_USER:$OSSE_GROUP "$SUBS_DIR"
chown $OSSE_USER:$OSSE_GROUP "$SPOOL_DIR"

cat > /etc/default/$OSSE <<EOF
#OSSE_CONF="$OSSE_DIR/conf/config.json"
#OSSE_LOG_DIR='$LOG_DIR'
EOF

cat > "$OSSE_DIR/bin/start-$OSSE.bash" <<EOF
#!/bin/bash
if [ -z "\$OSSE_CONF" ]; then
  OSSE_CONF='$OSSE_DIR/conf/config.json'
fi
if [ -z "\$OSSE_LOG_DIR" ]; then
  OSSE_LOG_DIR='$LOG_DIR'
fi
echo "starting $OSSE with conf:\$OSSE_CONF log dir:\$OSSE_LOG_DIR"
cd $OSSE_DIR/js
/usr/bin/nodejs $OSSE_DIR/js/osse-server.js --config=\$OSSE_CONF 1>>\${OSSE_LOG_DIR}/$OSSE.log 2>>\${OSSE_LOG_DIR}/$OSSE.error
echo "$OSSE exitcode \$?"
EOF
chmod +x $OSSE_DIR/bin/start-$OSSE.bash

cat > /etc/systemd/system/$OSSE.service <<EOF
[Unit]
Description=OSSE UI Server
Requires=network.target
After=network.target
[Service]
User=$OSSE_USER
Group=$OSSE_GROUP
EnvironmentFile=-/etc/default/$OSSE
ExecStart=$OSSE_DIR/bin/start-$OSSE.bash
Type=simple
[Install]
WantedBy=multi-user.target
EOF
systemctl daemon-reload &>> ${DEBUG}
systemctl enable $OSSE.service &>> ${DEBUG}


cd $OSSE_DIR/bin
wget -q https://raw.githubusercontent.com/hillar/detektiven/master/stuff/txt/osse/server/check-osse-subscriptions.bash
chmod +x check-osse-subscriptions.bash
cat > /etc/cron.d/check-osse-subscriptions << EOF
# check osse-server subscritions
# $(date) created by $0
SHELL=/bin/bash
PATH=/sbin:/bin:/usr/sbin:/usr/bin
MAILTO=root
*/15 * * * * $OSSE_USER $OSSE_DIR/bin/check-osse-subscriptions.bash $OSSE_DIR/conf/config.json 1> $LOG_DIR/subscriptions.log 2> $LOG_DIR/subscriptions.error
EOF

log "installed $OSSE to $OSSE_DIR"
log "$OSSE server will run on $HOST:$PORT "
log "config is $OSSE_DIR/conf/config.json"
log "subs cron file is /etc/cron.d/check-osse-subscriptions"
log "start $OSSE server with 'systemctl start $OSSE.service'"

log "done"
