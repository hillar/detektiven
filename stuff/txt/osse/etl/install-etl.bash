#!/bin/bash
#
# install etl_file.py
#
# python files /opt/etl/python
# config files /opt/etl/config
# executable /opt/etl/bin/etl-file.bash
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

[ -d "/vagrant" ] || mkdir /vagrant

ETL_DIR='/opt/etl'
SOLR_HOST='127.0.0.1'
SOLR_PORT='8983'
SOLR_CORE='solrdefalutcore'
TIKA_HOST='127.0.0.1'
TIKA_PORT='9998'

apt-get -y install jq >> /vagrant/provision.log 2>&1

rm -rf $ETL_DIR

cd /tmp
rm master.tar.gz*
wget -q https://github.com/opensemanticsearch/open-semantic-etl/archive/master.tar.gz
tar -xzf master.tar.gz
cd /tmp/open-semantic-etl-master/src/opensemanticetl
export LC_ALL=C
echo -en $(grep "Depends: " /tmp/open-semantic-etl-master/build/deb/stable/DEBIAN/control | sed 's/Depends: //'| sed 's/(>=0)//g' | sed 's/,/\\n/g') | grep python | while read p;
do
  #echo $p
  apt-get -y install $p >> /vagrant/provision.log 2>&1
done
##apt-get -y install jq python3-pip
#pip3 install scrapy

mkdir -p "$ETL_DIR/python"
cd $ETL_DIR/python
mv /tmp/open-semantic-etl-master/src/opensemanticetl/*.py .
wget -q https://raw.githubusercontent.com/hillar/detektiven/master/stuff/txt/osse/etl/enhance_file_md5.py
mkdir -p "$ETL_DIR/config"
cd "$ETL_DIR/config"
mv /tmp/open-semantic-etl-master/etc/opensemanticsearch/* .
mv etl etl.sample

cat > "$ETL_DIR/config/etl" <<EOF
config['force'] = False

config['tika_server'] = 'http://$TIKA_HOST:$TIKA_PORT'
config['export'] = 'export_solr'
config['solr'] = 'http://$SOLR_HOST:$SOLR_PORT/solr/'
config['index'] = '$SOLR_CORE'

config['mappings'] = { "/": "file:///" }
config['facet_path_strip_prefix'] = [ "file://" ]
config['plugins'] = [
  'enhance_mapping_id',
  'filter_blacklist',
  'enhance_file_md5',
  'enhance_file_mtime',
  'enhance_extract_text_tika_server',
  'enhance_contenttype_group',
  'enhance_pst',
  'enhance_zip',
  'clean_title'
]

config['plugins'].append('enhance_pdf_ocr')
config['plugins'].append('enhance_ocr_descew')
config['ocr_lang'] = 'est+eng+deu'
config['plugins'].append('enhance_regex')
config['regex_lists'] = ['$ETL_DIR/config/regex/email.tsv']

config['blacklist'] = ["$ETL_DIR/config/blacklist/blacklist-url"]
config['blacklist_prefix'] = ["$ETL_DIR/config/blacklist/blacklist-url-prefix"]
config['blacklist_suffix'] = ["$ETL_DIR/config/blacklist/blacklist-url-suffix"]
config['blacklist_regex'] = ["$ETL_DIR/config/blacklist/blacklist-url-regex"]
config['whitelist'] = ["$ETL_DIR/config/blacklist/whitelist-url"]
config['whitelist_prefix'] = ["$ETL_DIR/config/blacklist/whitelist-url-prefix"]
config['whitelist_suffix'] = ["$ETL_DIR/config/blacklist/whitelist-url-suffix"]
config['whitelist_regex'] = ["$ETL_DIR/config/blacklist/whitelist-url-regex"]
EOF

mkdir -p "$ETL_DIR/bin"

cat > "$ETL_DIR/bin/etl-file.bash" <<EOF
#!/bin/bash
SOLR="$SOLR_HOST:$SOLR_PORT"
CORE="$SOLR_CORE"
FILE="\$1"
log() { echo "\$(date) \$0: \$*"; }
error() { echo "\$(date) \$0: \$*" >&2; }
die() { error "\$*"; exit 1; }
md5=\$(md5sum "\$FILE"| cut -f1 -d" ")
existsTMP=\$(mktemp)
curl -s "http://\$SOLR/solr/\$CORE/select?fl=id,file_md5&wt=json&q=file_md5:\$md5" > \$existsTMP
[ \$? != 0 ] && die "solr down"
if [ ! \$(cat \$existsTMP | jq .response.docs[].file_md5 | grep  "\$md5" | wc -l) -eq 1 ]; then
  log "adding \$md5 \$FILE"
  python3 $ETL_DIR/python/etl_file.py --config="$ETL_DIR/config/etl" \$FILE
  # etl_file.py commit is broken, force it
  curl -s http://127.0.0.1:8983/solr/solrdefalutcore/update?commit=true > /dev/null
else
  if [ ! \$(cat \$existsTMP| grep "\$FILE"| wc -l ) -eq 1 ]; then
    error "file alias \$md5 \$FILE \$(cat \$existsTMP| grep "file\:///")"
  else
    log "file already indexed \$md5 \$FILE \$(cat \$existsTMP| grep "\$FILE")"
  fi
fi
rm \$existsTMP
EOF
chmod +x /opt/etl/bin/etl-file.bash
ln -s /opt/etl/bin/etl-file.bash /usr/local/bin/etl-file

tika=$(curl -s "http://$TIKA_HOST:$TIKA_PORT/tika"| wc -l)
if [ "$tika" == "0" ]; then
  echo "WARNING :  tika not running on $TIKA_HOST:$TIKA_PORT"
else
  echo "OK tika $TIKA_HOST:$TIKA_PORT"
fi

core=$(curl -s "http://$SOLR_HOST:$SOLR_PORT/solr/admin/cores?action=STATUS&core=$SOLR_CORE" | jq ".status.$SOLR_CORE.name"|sed 's/"//g')
if [ "$core" == "$SOLR_CORE" ]; then
  echo "OK solr core $core $SOLR_HOST:$SOLR_PORT"
else
  echo "WARNING :  core $core does not exists ($SOLR_CORE)"
  echo "           create with su -c '/opt/solr/bin/solr create -c $SOLR_CORE' solr"
fi
echo "installed etl to $ETL_DIR"
echo "using solr server  $SOLR_HOST:$SOLR_PORT core $SOLR_CORE"
echo "using tika server $TIKA_HOST:$TIKA_PORT"
echo "etl-file is in /usr/local/bin/etl-file"
echo "$(date) done $0"
