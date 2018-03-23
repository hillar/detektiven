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
CLAMAV_HOST='127.0.0.1'
CLAMAV_PORT='3310'
METAFILE='meta.json.xz'
MD5FIELDNAME='file_md5_s'

apt-get -y install python3 jq >> /vagrant/provision.log 2>&1
apt-get -y install tesseract-ocr tesseract-ocr-deu tesseract-ocr-est tesseract-ocr-rus tesseract-ocr-eng >> /vagrant/provision.log 2>&1

cd /tmp
[ -f master.tar.gz ] && rm master.tar.gz*
wget -q https://github.com/opensemanticsearch/open-semantic-etl/archive/master.tar.gz
tar -xzf master.tar.gz
rm master.tar.gz
cd /tmp/open-semantic-etl-master/src/opensemanticetl
export LC_ALL=C
echo -en $(grep "Depends: " /tmp/open-semantic-etl-master/build/deb/stable/DEBIAN/control | sed 's/Depends: //'| sed 's/(>=0)//g' | sed 's/,/\\n/g') | grep python | while read p;
do
  #echo $p
  apt-get -y install $p >> /vagrant/provision.log 2>&1
done
##apt-get -y install jq python3-pip
#pip3 install scrapy
pip3 install pyclamd

mkdir -p "$ETL_DIR/python"
cd $ETL_DIR/python
mv /tmp/open-semantic-etl-master/src/opensemanticetl/*.py .
wget -q https://raw.githubusercontent.com/hillar/detektiven/master/stuff/txt/osse/etl/enhance_file_md5.py
wget -q https://raw.githubusercontent.com/hillar/detektiven/master/stuff/txt/osse/etl/enhance_file_meta.py
wget -q https://raw.githubusercontent.com/hillar/detektiven/master/stuff/txt/osse/etl/enhance_file_clam.py
wget -q https://raw.githubusercontent.com/hillar/detektiven/master/stuff/txt/osse/etl/enhance_tika_und_clam.py
mkdir -p "$ETL_DIR/config"
cd "$ETL_DIR/config"
mv /tmp/open-semantic-etl-master/etc/opensemanticsearch/* .
mv etl etl.sample

TAB="$(printf '\t')"
cat > /opt/etl/config/regex/email.tsv <<EOF
[A-Z0-9a-z._%+-]+@[A-Za-z0-9.-]+\\.[A-Za-z]{2,64}${TAB}email_s
[13][a-km-zA-HJ-NP-Z1-9]{25,34}${TAB}bitcoin_s
[a-zA-Z]{2}[0-9]{2}[a-zA-Z0-9]{4}[0-9]{7}([a-zA-Z0-9]?){0,16}${TAB}iban_s
#https://ipsec.pl/data-protection/2012/european-personal-data-regexp-patterns.html
[3-6][0-9]{2}[1,2][0-9][0-9]{2}[0-9]{4}${TAB}ssn_s
[0-9]{2}[0,1][0-9][0-9]{2}-[A-Z]-[0-9]{5}${TAB}ssn_s
[0-9]{3}/?[0-9]{4}/?[0-9]{4}${TAB}ssn_s
[0-9]{2}[0-9]{2}[0,1][0-9][0-9]{2}[A-Z][0-9]{2}[0-9]${TAB}ssn_s
[0-9]{2}[0,1][0-9][0-9]-[0-9]{5}ssn_s
EOF

cat > "$ETL_DIR/config/etl" <<EOF
config['force'] = False

config['clamd_host'] = '$CLAMAV_HOST'
config['clamd_port'] = $CLAMAV_PORT
config['tika_server'] = 'http://$TIKA_HOST:$TIKA_PORT'

config['export'] = 'export_solr'
config['solr'] = 'http://$SOLR_HOST:$SOLR_PORT/solr/'
config['index'] = '$SOLR_CORE'

config['mappings'] = { "/": "file:///" }
config['facet_path_strip_prefix'] = [ "file://" ]
config['plugins'] = [
  'filter_blacklist',
  'enhance_zip',
  'enhance_tika_und_clam',
  'enhance_mapping_id',
  'enhance_file_md5',
  'enhance_file_mtime',
  'enhance_contenttype_group',
  'enhance_pst',
  'clean_title'
]

config['md5_field_name']='$MD5FIELDNAME'

config['enhance_file_meta_filename'] = 'meta.json.xz'
config['plugins'].append('enhance_file_meta')

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
META="$METAFILE"
MD5F="$MD5FIELDNAME"
FILE="\$1"
log() { echo "\$(date) \$0: \$*"; }
error() { echo "\$(date) \$0: \$*" >&2; }
die() { error "\$*"; exit 1; }
md5=\$(md5sum "\$FILE"| cut -f1 -d" ")
existsTMP=\$(mktemp)
curl -s "http://\$SOLR/solr/\$CORE/select?fl=id,\$MD5F,aliases&wt=json&q=\$MD5F:\$md5" > \$existsTMP
[ \$? != 0 ] && die "solr down"
#TODO .response.docs[].[\$MD5F]
if [ \$(cat \$existsTMP | jq .response.docs[] | grep  "\$md5" | wc -l) -eq 0 ]; then
  log "adding \$md5 \$FILE"
  python3 $ETL_DIR/python/etl_file.py --config="$ETL_DIR/config/etl" \$FILE
  # etl_file.py commit is broken, force it
  curl -s http://127.0.0.1:8983/solr/solrdefalutcore/update?commit=true > /dev/null
else
  if [ \$(cat \$existsTMP| grep "\$FILE"| wc -l ) -eq 0 ]; then
      id=\$(cat \$existsTMP| jq .response.docs[0].id)
      dirname=\$(dirname \$FILE)
      metafile="\$dirname/\$META"
      if [ -f "\$metafile" ];then
        curl -s -X POST -H 'Content-Type: application/json' "http://\$SOLR/solr/\$CORE/update?commit=true" --data-binary "[{\"id\":\"\$FILE\",\"alias_for\":\$id,\$(xzcat \$metafile|sed 's/{//'| sed 's/}//')}]" > /dev/null
        log "added meta \$md5 \$FILE "
      fi
      curl -s -X POST -H 'Content-Type: application/json' "http://\$SOLR/solr/\$CORE/update?commit=true" --data-binary "[{\"id\":\$id,\"aliases\":{\"add\":[\"\$FILE\"]}}]" > /dev/null
      log "added alias \$md5 \$id \$FILE"
  else
    log "file already indexed \$md5 \$FILE \$(cat \$existsTMP| grep "\$FILE"|wc -l)"
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
