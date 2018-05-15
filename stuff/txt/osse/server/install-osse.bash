#!/bin/bash
#
# install OSSE
#
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

IP=$1
[ -z $1 ] && IP="127.0.0.1"
IPAHOST=$2
[ -z $2 ] && IPAHOST="127.0.0.1"

OSSE='osse-server'
OSSE_DIR="/opt/$OSSE"
HOST=$IP
PORT='9983'
MD5FIELDNAME='file_md5_s'

OSSE_USER=$OSSE
OSSE_GROUP=$OSSE
OSSE_DIR="/opt/$OSSE"
LOG_DIR="/var/log/$OSSE"
DATA_DIR="/var/data/$OSSE"
SESS_DIR="$DATA_DIR/session"
SUBS_DIR="$DATA_DIR/subscritions"
SPOOL_DIR="$DATA_DIR/spool"


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
  apt-get -y upgrade >> /vagrant/provision.log 2>&1
  apt-get -y install nodejs
fi
if [ ! -d /provision/detektiven-master/stuff/txt/osse ]; then
  [ -d /provision ] || mkdir /provision
  cd /provision/
  [ -f master.tar.gz ] && rm master.tar.gz
  wget -q https://github.com/hillar/detektiven/archive/master.tar.gz
  tar -xzf master.tar.gz
  rm master.tar.gz
fi

addgroup --system "$OSSE_GROUP" --quiet
adduser --system --home $OSSE_DIR --no-create-home --ingroup $OSSE_GROUP --disabled-password --shell /bin/false "$OSSE_USER" --quiet

mkdir -p "$OSSE_DIR/bin"
mkdir -p "$OSSE_DIR/conf"
mkdir -p "$OSSE_DIR/js"
cd "$OSSE_DIR/js"
cp /provision/detektiven-master/stuff/txt/osse/server/* .
#TODO replace this ugly hack with some sane bundler....
mkdir common
cd common
grep common ../osse-server.js | grep -v '//'| cut -f2 -d"'"| cut -f3 -d"/"| while read f;
do
  wget -q https://raw.githubusercontent.com/hillar/detektiven/master/stuff/txt/osse/common/$f
done
cd ..
npm install --unsafe-perm >> /vagrant/provision.log 2>&1
npm rebuild --update-binary lzma-native >> /vagrant/provision.log 2>&1
cd /provision/detektiven-master/stuff/txt/osse/browser/osse-browser
npm install >> /vagrant/provision.log 2>&1
npm run build >> /vagrant/provision.log 2>&1
mv dist "$OSSE_DIR/js"
cd "$OSSE_DIR/js"
cp dist/static/favicon.ico dist/
mkdir -p $LOG_DIR
mkdir -p $DATA_DIR
mkdir -p $SESS_DIR
mkdir -p $SUBS_DIR
mkdir -p $SPOOL_DIR
#node osse-server.js -g > ../conf/config.json
cat > $OSSE_DIR/conf/config.json <<EOF
{
  "portListen": "$PORT",
  "ipBind": "$HOST",
  "ipaServer": "$IPAHOST",
  "usersFile": "$SESS_DIR/users.json",
  "uploadDirectory": "$SPOOL_DIR",
  "subscriptionsDirectory": "$SUBS_DIR",
  "staticDirectory": "$OSSE_DIR/js/dist",
  "md5Fieldname":"$MD5FIELDNAME"
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
systemctl daemon-reload
systemctl enable $OSSE.service >> /vagrant/provision.log 2>&1

echo "installed $OSSE to $OSSE_DIR"
echo "$OSSE server will run on $HOST:$PORT "
echo "config is $OSSE_DIR/conf/config.json"
echo "start $OSSE server with 'systemctl start $OSSE.service'"

echo "$(date) done $0"
