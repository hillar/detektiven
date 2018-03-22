#!/bin/bash
#
# install OSSE + TIKA + SOLR + fileserver + ETL(python)
# download vagrantfile and this install script
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

IP=$1
[ -z $1 ] && IP="192.168.11.2"
IPA=$2
[ -z $2 ] && IPA="192.168.10.2"

[ -d "/vagrant" ] || mkdir /vagrant
export LC_ALL=C
[ -d /provision ] || mkdir /provision


# install clamav
# TODO move it to separate machine as freeipa
apt-get -y install clamav-daemon
systemctl stop clamav-daemon.socket
systemctl disable clamav-daemon.socket
systemctl stop clamav-daemon.service
rm /lib/systemd/system/clamav-daemon.socket
cat > /lib/systemd/system/clamav-daemon.service << EOF
[Unit]
Description=Clam AntiVirus userspace daemon
ConditionPathExistsGlob=/var/lib/clamav/main.{c[vl]d,inc}
ConditionPathExistsGlob=/var/lib/clamav/daily.{c[vl]d,inc}
[Service]
ExecStart=/usr/sbin/clamd --foreground=true
ExecReload=/bin/kill -USR2 $MAINPID
StandardOutput=syslog
[Install]
WantedBy=multi-user.target
EOF
systemctl daemon-reload
systemctl enable clamav-daemon.service

cat > /etc/clamav/clamd.conf <<EOF
User clamav
TCPSocket 3310
TCPAddr 127.0.0.1
AllowSupplementaryGroups false
ScanMail true
ScanArchive true
ArchiveBlockEncrypted false
MaxDirectoryRecursion 15
FollowDirectorySymlinks false
FollowFileSymlinks false
ReadTimeout 180
MaxThreads 12
MaxConnectionQueueLength 15
LogSyslog false
LogRotate true
LogFacility LOG_LOCAL6
LogClean false
LogVerbose true
DatabaseDirectory /var/lib/clamav
OfficialDatabaseOnly false
SelfCheck 3600
Foreground false
Debug false
ScanPE true
MaxEmbeddedPE 10M
ScanOLE2 true
ScanPDF true
ScanHTML true
MaxHTMLNormalize 10M
MaxHTMLNoTags 2M
MaxScriptNormalize 5M
MaxZipTypeRcg 1M
ScanSWF true
DetectBrokenExecutables false
ExitOnOOM false
LeaveTemporaryFiles false
AlgorithmicDetection true
ScanELF true
IdleTimeout 30
CrossFilesystems true
PhishingSignatures true
PhishingScanURLs true
PhishingAlwaysBlockSSLMismatch false
PhishingAlwaysBlockCloak false
PartitionIntersection false
DetectPUA false
ScanPartialMessages false
HeuristicScanPrecedence false
StructuredDataDetection false
CommandReadTimeout 5
SendBufTimeout 200
MaxQueue 100
ExtendedDetectionInfo true
OLE2BlockMacros false
ScanOnAccess false
AllowAllMatchScan true
ForceToDisk false
DisableCertCheck false
DisableCache false
MaxScanSize 100M
MaxFileSize 25M
MaxRecursion 16
MaxFiles 10000
MaxPartitions 50
MaxIconsPE 100
PCREMatchLimit 10000
PCRERecMatchLimit 5000
PCREMaxFileSize 25M
ScanXMLDOCS true
ScanHWP3 true
MaxRecHWP3 16
StatsEnabled false
StatsPEDisabled true
StatsHostID auto
StatsTimeout 10
StreamMaxLength 25M
LogFile /var/log/clamav/clamav.log
LogTime true
LogFileUnlock false
LogFileMaxSize 0
Bytecode true
BytecodeSecurity TrustSigned
BytecodeTimeout 60000
EOF

cd /provision/
[ -f master.tar.gz ] && rm master.tar.gz
wget -q https://github.com/hillar/detektiven/archive/master.tar.gz
tar -xzf master.tar.gz
rm master.tar.gz
bash /provision/detektiven-master/stuff/txt/osse/tika/install-tika.bash
systemctl start tika.service
bash /provision/detektiven-master/stuff/txt/osse/solr/install-solr.bash
systemctl start solr.service
bash /provision/detektiven-master/stuff/txt/osse/elasticsearch/install-elastic.bash
systemctl start elasticsearch.service
bash /provision/detektiven-master/stuff/txt/osse/etl/install-etl.bash
bash /provision/detektiven-master/stuff/txt/osse/fileserver/install-fileserver.bash
systemctl start osse-fileserver-news-monitor.service
systemctl start systemctl start osse-fileserver.service
bash /provision/detektiven-master/stuff/txt/osse/server/install-osse.bash $IP $IPA
systemctl start osse-server.service
# run clam as late as possible to let freshclam to download db
systemctl start clamav-daemon.service

touch /tmp/empty.file
f=/tmp/empty.file
curl -s -XPOST -F "data=@$f" -F "tags=TEST" -H "Content-Type: multipart/form-data" -uuploadonly:uploadonly "$IP:9983/files"
sleep 3
etl-file /tmp/empty.file
