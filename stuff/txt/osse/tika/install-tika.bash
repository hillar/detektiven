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

XENIAL=$(lsb_release -c | cut -f2)
if [ "$XENIAL" != "xenial" ]; then
    echo "sorry, tested only with xenial ;("; 1>&2
    exit1;
fi

if [ "$(id -u)" != "0" ]; then
   echo "ERROR - This script must be run as root" 1>&2
   exit 1
fi

#stupid systemclt ...
export SYSTEMD_PAGER=''

TIKA='tika'
VER='1.17'
MINMEM='512m'
MAXMEM='2048m'

TIKA_USER=$TIKA
TIKA_GROUP=$TIKA
TIKA_DIR="/opt/$TIKA"
LOG_DIR="/var/log/$TIKA"

mkdir -p "$TIKA_DIR/bin"
mkdir -p "$TIKA_DIR/jar"
cd "$TIKA_DIR/jar"
[ -f "tika-server-.$VER.jar" ] || wget -q "http://www-eu.apache.org/dist/tika/tika-server-$VER.jar"
md5sum "tika-server-.$VER.jar"

addgroup --system "$TIKA_GROUP" --quiet
adduser --system --home $TIKA_DIR --no-create-home --ingroup $TIKA_GROUP --disabled-password --shell /bin/false "$TIKA_USER"

mkdir -p $LOG_DIR
chown $TIKA_USER:$TIKA_GROUP "$LOG_DIR"

cat > /etc/default/tika <<EOF
# Additional Java OPTS
TIKA_JAVA_OPTS="-Xms$MINMEM -Xmx$MAXMEM"
# Tika logs directory
# Error log can be VERY noisy
TIKA_LOG_DIR="$LOG_DIR"
#TIKA_HOST='127.0.0.1'
#TIKA_PORT='9998'
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

cat > /etc/systemd/system//tika.service <<EOF
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
systemctl daemon-reload
systemctl enable tika.service
systemctl start tika.service
sleep 1
systemctl status tika.service
systemctl stop tika.service
sleep 1
systemctl status tika.service
