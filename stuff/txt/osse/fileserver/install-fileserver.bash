#!/bin/bash
#
# install fileserver
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

FS='osse-fileserver'
FS_DIR="/opt/$FS"
HOST='127.0.0.1'
PORT='8125'

FS_USER=$FS
FS_GROUP=$FS
FS_DIR="/opt/$FS"
LOG_DIR="/var/log/$FS"
FILE_DIR="/var/data/$FS/$(hostname)"

[ -d "/vagrant" ] || mkdir /vagrant

export SYSTEMD_PAGER=''
export LC_ALL=C
export DEBIAN_FRONTEND=noninteractive

node=$(nodejs -v)
if [ "$node" != "" ]; then
  echo "$(date) nodejs ver $node"
else
  echo "$(date) installing nodejs"
  curl -sL https://deb.nodesource.com/setup_9.x | sudo -E bash - >> /vagrant/provision.log 2>&1
  # apt-get update >> /vagrant/provision.log 2>&1
  apt-get -y upgrade >> /vagrant/provision.log 2>&1
  apt-get -y install nodejs >> /vagrant/provision.log 2>&1
fi

addgroup --system "$FS_GROUP" --quiet
adduser --system --home $FS_DIR --no-create-home --ingroup $FS_GROUP --disabled-password --shell /bin/false "$FS_USER" --quiet


mkdir -p "$FS_DIR/bin"
mkdir -p "$FS_DIR/js"
cd "$FS_DIR/js"
wget -q https://raw.githubusercontent.com/hillar/detektiven/master/stuff/txt/osse/fileserver/package.json
wget -q https://raw.githubusercontent.com/hillar/detektiven/master/stuff/txt/osse/fileserver/file-server.js
npm install >> /vagrant/provision.log 2>&1

mkdir -p $LOG_DIR
mkdir -p $FILE_DIR
chown -R $FS_USER:$FS_GROUP "$FS_DIR"
chown $FS_USER:$FS_GROUP "$LOG_DIR"
chown $FS_USER:$FS_GROUP "$FILE_DIR"

cat > /etc/default/$FS <<EOF
FS_HOST='$HOST'
FS_PORT='$PORT'
FS_FILE_DIR="$FILE_DIR"
FS_LOG_DIR="$LOG_DIR"
EOF

cat > "$FS_DIR/bin/start-$FS.bash" <<EOF
#!/bin/bash
if [ -z "\$FS_FILE_DIR" ]; then
  echo "warning: log dir FS_LOG_DIR not set; setting to $(pwd) "
  FS_FILE_DIR='$(pwd)'
fi
if [ "\$FS_FILE_DIR" == "" ]; then
  echo "warning: log dir FS_LOG_DIR empty; setting to $(pwd) "
  FS_FILE_DIR='$(pwd)'
fi
if [ -z "\$FS_LOG_DIR" ]; then
  echo "warning: log dir FS_LOG_DIR not set; setting to /tmp "
  FS_LOG_DIR='/tmp'
fi
if [ -z "\$FS_HOST" ]; then
  FS_HOST='127.0.0.1'
fi
if [ -z "\$FS_PORT" ]; then
  FS_PORT='8125'
fi
echo "starting $FS \${FS_HOST}:\${FS_PORT} file dir: \${FS_FILE_DIR} log dir: \${FS_LOG_DIR}"
cd /opt/$FS/js
/usr/bin/nodejs /opt/$FS/js/file-server.js --port=\${FS_PORT} --ip=\${FS_HOST} --root=\${FS_FILE_DIR} 1>\${FS_LOG_DIR}/$FS.log 2>\${FS_LOG_DIR}/$FS.error
echo "$FS exit code \$?"
EOF

chmod +x "$FS_DIR/bin/start-$FS.bash"

cat > /etc/systemd/system/$FS.service <<EOF
[Unit]
Description=OSSE File Server
Requires=network.target
After=network.target
[Service]
User=$FS_USER
Group=$FS_GROUP
EnvironmentFile=-/etc/default/$FS
ExecStart=$FS_DIR/bin/start-$FS.bash
Type=simple
[Install]
WantedBy=multi-user.target
EOF
systemctl daemon-reload
systemctl enable $FS.service >> /vagrant/provision.log 2>&1

echo "installed $FS to $FS_DIR"
echo "$FS server will run on $HOST:$PORT "
echo "file dir is $FILE_DIR"
echo "log dir is $LOG_DIR"
echo "start $FS server with 'systemctl start $FS.service'"

echo "$(date) done $0"
