#!/bin/bash
#
# install TIKA as systemd service
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
VER='17'

TIKA_USER=$TIKA
TIKA_GROUP=$TIKA
TIKA_DIR="/opt/$TIKA"
LOG_DIR="/var/log/$TIKA"

mkdir -p $TIKA_DIR
cd $TIKA_DIR
wget -q "http://www-eu.apache.org/dist/tika/tika-server-1.$VER.jar"

addgroup --system "$TIKA_GROUP" --quiet
adduser --system --home $TIKA_DIR --no-create-home --ingroup $TIKA_GROUP --disabled-password --shell /bin/false "$TIKA_USER"

mkdir -p $LOG_DIR
chown $TIKA_USER:$TIKA_GROUP "$LOG_DIR"

cat > /usr/lib/systemd/system/tika.service <<EOF
[Unit]
Description=Apache Tika Server
Requires=network.target
After=network.target
[Service]
User=tika
Group=tika
ExecStart=/bin/sh -c '/usr/bin/java -jar /opt/tika/tika-server-1.$VER.jar 1>$LOG_DIR/tika.log 2>$LOG_DIR/tika.error'
# SIGTERM signal is used to stop the Java process
#KillSignal=SIGTERM
# Send the signal only to the JVM rather than its control group
#KillMode=process
# Java process is never killed
#SendSIGKILL=no
# When a JVM receives a SIGTERM signal it exits with code 143
#SuccessExitStatus=143
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
