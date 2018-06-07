#!/bin/bash
#
# install TIKA
#
# enviroment variables /etc/default/tika
# start script /opt/tika/bin/start-tika.bash
# systemctl service tika.service
#
# ! tika error log is VERY verbose
#

#stupid systemclt ...
export SYSTEMD_PAGER=''
export LC_ALL=C

TIKA='tika'
VER='1.18'
HOST='0.0.0.0'
[ -z $1 ] || HOST=$1
PORT='9998'
MINMEM='512m'
MAXMEM='2048m'

TIKA_USER=$TIKA
TIKA_GROUP=$TIKA
TIKA_DIR="/opt/$TIKA"
LOG_DIR="/var/log/$TIKA"


java=$(java -version 2>&1 | awk -F '"' '/version/ {print $2}')
if [ "$java" != "" ]; then
  echo "$(date) java ver $java "
else
  echo "no java"
  exit 1
fi

mkdir -p "$TIKA_DIR/bin"
mkdir -p "$TIKA_DIR/jar"
cd "$TIKA_DIR/jar"
[ -f "tika-server-$VER.jar" ] || wget -q "http://archive.apache.org/dist/tika/tika-server-${VER}.jar"
md5sum "tika-server-$VER.jar"

groupadd --system "$TIKA_GROUP" || addgroup --system "$TIKA_GROUP" --quiet
adduser --system --home $TIKA_DIR --no-create-home --gid $TIKA_GROUP --shell /bin/false "$TIKA_USER" || adduser --system --home $TIKA_DIR --no-create-home --ingroup $TIKA_GROUP --disabled-password --shell /bin/false "$TIKA_USER" --quiet
mkdir -p $LOG_DIR
chown $TIKA_USER:$TIKA_GROUP "$LOG_DIR"

cat > /etc/default/tika <<EOF
# Additional Java OPTS
TIKA_JAVA_OPTS='-Xms$MINMEM -Xmx$MAXMEM'
# Tika logs directory
# Error log can be VERY noisy
TIKA_LOG_DIR="$LOG_DIR"
TIKA_HOST='$HOST'
TIKA_PORT='$PORT'
#TIKA_DIGEST='md5'
EOF

cat > "$TIKA_DIR/bin/start-tika.bash" <<EOF
#!/bin/bash
if [ ! -z "\$JAVA_OPTS" ]; then
  echo -n "warning: ignoring JAVA_OPTS=\$JAVA_OPTS; "
  echo "pass JVM parameters via TIKA_JAVA_OPTS"
fi
if [ -z "\$TIKA_LOG_DIR" ]; then
  echo "warning: log dir TIKA_LOG_DIR not set; setting to /tmp "
  TIKA_LOG_DIR='/tmp'
fi
if [ -z "\$TIKA_HOST" ]; then
  TIKA_HOST='127.0.0.1'
fi
if [ -z "\$TIKA_PORT" ]; then
  TIKA_PORT='9998'
fi
if [ -z "\$TIKA_DIGEST" ]; then
  TIKA_DIGEST='md5'
fi
echo "starting tika \${TIKA_HOST}:\${TIKA_PORT} with java opts:\${TIKA_JAVA_OPTS} log dir: \${TIKA_LOG_DIR}"
/usr/bin/java \${TIKA_JAVA_OPTS} -jar /opt/tika/jar/tika-server-$VER.jar --port \${TIKA_PORT} --host \${TIKA_HOST} --digest \${TIKA_DIGEST} 1>\${TIKA_LOG_DIR}/tika.log 2>\${TIKA_LOG_DIR}/tika.error
echo "tika exit code \$?"
EOF

chmod +x "$TIKA_DIR/bin/start-tika.bash"

cat > /etc/systemd/system/tika.service <<EOF
[Unit]
Description=Apache Tika Server
Requires=network.target
After=network.target
[Service]
User=$TIKA_USER
Group=$TIKA_GROUP
EnvironmentFile=-/etc/default/tika
ExecStart=$TIKA_DIR/bin/start-tika.bash
Type=simple
[Install]
WantedBy=multi-user.target
EOF
systemctl daemon-reload >> /tmp/provision.log 2>&1
systemctl enable tika.service >> /tmp/provision.log 2>&1
systemctl start tika.service >> /tmp/provision.log 2>&1

echo "installed tika to $TIKA_DIR"
echo "tika server will run on $HOST:$PORT "
echo "log dir is $LOG_DIR"
echo "start tika server with 'systemctl start tika.service'"
echo "$(date) done $0"
