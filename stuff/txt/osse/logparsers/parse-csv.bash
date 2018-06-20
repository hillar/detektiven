log() { echo "$(date) $0: $*"; }
die() { log "$*" >&2; exit 1; }

file=$1
[ -z ${file} ] && die "no file"

CORE=solrdefalutcore
[ -z $2 ] || CORE=$2

HOST=127.0.0.1
[ -z $3 ] || HOST=$3

filemd5=$(md5sum ${file} | awk '{print $1}')
log "started $HOST/$CORE <-  $filemd5 $file"

zcat ${file}| head -100 |jq -c -R -s -f csv2json.jq | while read l; do
    linemd5=$(echo "$l" | md5sum | awk '{print $1}')
    json=$(echo $l |sed 's/" /"/g'| jq --arg filemd5 $filemd5  --arg linemd5 $linemd5 '. += {LOGFILE:$filemd5,id:$linemd5} | remove_empty') || die "$l"
    curl  -s -X POST -H 'Content-Type: application/json' \
    "http://${HOST}:8983/solr/${CORE}/update/json/docs" \
    --data-binary "${json}" > /dev/null || die 'solr error'
done
curl "http://${HOST}:8983/solr/${CORE}/update?commit=true"
log "done with $file"
