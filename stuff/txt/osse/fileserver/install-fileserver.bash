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
METAFILE='meta.json'
max_user_watches='524288'

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
 apt-get -y install inotify-tools >> /vagrant/provision.log 2>&1

addgroup --system "$FS_GROUP" --quiet
adduser --system --home $FS_DIR --no-create-home --ingroup $FS_GROUP --disabled-password --shell /bin/false "$FS_USER" --quiet
#TODO cat /proc/sys/fs/inotify/max_user_watches
sysctl fs.inotify.max_user_watches=$max_user_watches

mkdir -p "$FS_DIR/bin"
mkdir -p "$FS_DIR/js"
cd "$FS_DIR/js"
wget -q https://raw.githubusercontent.com/hillar/detektiven/master/stuff/txt/osse/fileserver/package.json
wget -q https://raw.githubusercontent.com/hillar/detektiven/master/stuff/txt/osse/fileserver/file-server.js
#TODO replace this ugly hack with some sane bundler....
mkdir common
cd common
grep common ../file-server.js | grep -v '//'| cut -f2 -d"'"| cut -f3 -d"/"| while read f;
do
  wget -q https://raw.githubusercontent.com/hillar/detektiven/master/stuff/txt/osse/common/$f
done
cd ..
npm install >> /vagrant/provision.log 2>&1

mkdir -p $LOG_DIR
mkdir -p /var/log/$FS-monitor
mkdir -p $FILE_DIR
chown -R $FS_USER:$FS_GROUP "$FS_DIR"
chown $FS_USER:$FS_GROUP "$LOG_DIR"
chown $FS_USER:$FS_GROUP "$FILE_DIR"
chown $FS_USER:$FS_GROUP "/var/log/$FS-monitor"

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
if [ -z "\$FS_META" ]; then
  FS_PORT='$METAFILE'
fi
echo "starting $FS \${FS_HOST}:\${FS_PORT} file dir: \${FS_FILE_DIR} log dir: \${FS_LOG_DIR}"
cd /opt/$FS/js
/usr/bin/nodejs /opt/$FS/js/file-server.js --port=\${FS_PORT} --ip=\${FS_HOST} --root=\${FS_FILE_DIR} --meta=\${FS_META} 1>>\${FS_LOG_DIR}/$FS.log 2>>\${FS_LOG_DIR}/$FS.error
echo "$FS exit code \$?"
EOF

chmod +x "$FS_DIR/bin/start-$FS.bash"

cat > /etc/systemd/system/$FS.service <<EOF
[Unit]
Description=OSSE File Server
Requires=network.target $FS-spool-monitor.service
After=network.target $FS-spool-monitor.service
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

cat > /etc/default/$FS-monitor <<EOF
SPOOL_DIR='$FILE_DIR'
LOG_DIR='/var/log/$FS-monitor'
NEWS_FILE="$FILE_DIR/new-dirs.txt"
META_FILE="$METAFILE"
EOF

cat > "$FS_DIR/bin/$FS-spool-monitor.bash" <<EOF
#!/bin/bash
# watches fileserver \$FILE_DIR $FILE_DIR
# if not xz packed, packs
# and writes new dirnames to \$NEWS_FILE $FILE_DIR/new-dirs.txt
source /etc/default/$FS-monitor
echo "\$(date) \$0 pid \$\$ scanning \$SPOOL_DIR news to \$NEWS_FILE" >> \$LOG_DIR/spool-\$\$.log
cd \$SPOOL_DIR
# at start scan full spool
find ./ -type d | while read dirname
do
  find "\$dirname" -type f | while read f; do file \$f; done| grep -v "XZ compressed data" | cut -f1 -d":"| while read filename
  do
    xz -9e \$filename 1>> \$LOG_DIR/spool-\$\$.log 2>>\$LOG_DIR/spool-\$\$.error
    echo "\$(date) \$0 pid \$\$ packed old \$filename" >> \$LOG_DIR/spool-\$\$.log
    echo "\$dirname"
  done | sort | uniq >> \$NEWS_FILE
done
# watch for changes
echo "\$(date)  \$0 pid \$\$ watching \$SPOOL_DIR news to \$NEWS_FILE" >> \$LOG_DIR/spool-\$\$.log
while read tmp
do
    echo "\$tmp" | grep "\$META_FILE" | while read meta
    do
      dirname=\$(echo "\$meta"| cut -f1 -d" ")
      find "\$dirname" -type f | while read f; do file \$f; done| grep -v "XZ compressed data" | cut -f1 -d":"| while read filename
      do
        xz -9e \$filename 1>> \$LOG_DIR/spool-\$\$.log 2>>\$LOG_DIR/spool-\$\$.error
        echo "\$(date) \$0 pid \$\$ packed \$filename" >> \$LOG_DIR/spool-\$\$.log
        echo "\$dirname"
      done | sort | uniq >> \$NEWS_FILE
    done
done < <(inotifywait -mr -e close_write ./)
echo "\$(date) stopped \$0 pid \$\$ exit code \$?" >> \$LOG_DIR/spool-\$\$.log
EOF
chmod +x "$FS_DIR/bin/$FS-spool-monitor.bash"

cat > /etc/systemd/system/$FS-spool-monitor.service <<EOF
[Unit]
Description=OSSE File Spool Monitor
Requires=$FS-news-monitor.service
After=$FS-news-monitor.service
[Service]
User=$FS_USER
Group=$FS_GROUP
EnvironmentFile=-/etc/default/$FS-monitor
ExecStart=$FS_DIR/bin/$FS-spool-monitor.bash
Type=simple
[Install]
WantedBy=multi-user.target
EOF
systemctl daemon-reload
systemctl enable $FS-spool-monitor.service >> /vagrant/provision.log 2>&1


cat > "$FS_DIR/bin/$FS-news-monitor.bash" <<EOF
#!/bin/bash
# tails \$NEWS_FILE $FILE_DIR/new-dirs.txt
# and feeds files in new dir one by one etl-file
source /etc/default/$FS-monitor
cd \$SPOOL_DIR
echo "\$(date) starting \$0 pid \$\$ \$(pwd)" >> \$LOG_DIR/news-\$\$.log
tail --lines=0 -F \$NEWS_FILE | while read dirname
do
  echo "\$(date) \$0 pid \$\$ new files in \$dirname" >> \$LOG_DIR/news-\$\$.log
  ls \$dirname/* | grep -v "\$META_FILE"| while read filename
  do
    etl-file \$filename 1>> \$LOG_DIR/news-\$\$.log 2>> \$LOG_DIR/news-\$\$.error
  done
done
echo "\$(date) stop \$0 pid \$\$ exit code \$?" >> \$LOG_DIR/news-\$\$.log
EOF
chmod +x "$FS_DIR/bin/$FS-news-monitor.bash"

cat > /etc/systemd/system/$FS-news-monitor.service <<EOF
[Unit]
Description=OSSE File Spool NEWS Monitor
[Service]
User=$FS_USER
Group=$FS_GROUP
EnvironmentFile=-/etc/default/$FS-monitor
ExecStart=$FS_DIR/bin/$FS-news-monitor.bash
Type=simple
[Install]
WantedBy=multi-user.target
EOF
systemctl daemon-reload
systemctl enable $FS-news-monitor.service >> /vagrant/provision.log 2>&1

echo "installed $FS to $FS_DIR"
echo "$FS server will run on $HOST:$PORT "
echo "file dir is $FILE_DIR"
echo "log dir is $LOG_DIR"
echo "start $FS news monitor with 'systemctl start $FS-news-monitor.service'"
echo "start $FS spool monitor with 'systemctl start $FS-spool-monitor.service'"
echo "start $FS server with 'systemctl start $FS.service'"

echo "$(date) done $0"
