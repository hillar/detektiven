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

ETL_DIR='/opt/etl'

rm -rf $ETL_DIR

cd /tmp
rm master.tar.gz*
wget https://github.com/opensemanticsearch/open-semantic-etl/archive/master.tar.gz
tar -xzf master.tar.gz
cd /tmp/open-semantic-etl-master/src/opensemanticetl
export LC_ALL=C
pip3 install scrapy
echo -en $(grep "Depends: " /tmp/open-semantic-etl-master/build/deb/stable/DEBIAN/control | sed 's/Depends: //'| sed 's/(>=0)//g' | sed 's/,/\\n/g') | grep python | while read p;
do
  echo $p
  apt-get -y install $p
done
apt-get -y install python3-pip
pip3 install scrapy

mkdir -p "$ETL_DIR/python"
cd $ETL_DIR/python
mv /tmp/open-semantic-etl-master/src/opensemanticetl/*.py .
mkdir -p "$ETL_DIR/config"
cd "$ETL_DIR/config"
mv /tmp/open-semantic-etl-master/etc/opensemanticsearch/* .
mv etl etl.sample

cat > "$ETL_DIR/config/etl" <<EOF
config['force'] = False
config['mappings'] = { "/": "file:///" }
config['facet_path_strip_prefix'] = [ "file://" ]
config['plugins'] = [
  'enhance_mapping_id',
  'filter_blacklist',
  'enhance_extract_text_tika_server',
  'enhance_contenttype_group',
  'enhance_pst',
  'enhance_file_mtime',
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
python3 $ETL_DIR/python/etl_file.py --config="$ETL_DIR/config/etl" \$1

EOF


echo "$(date) done $0"
