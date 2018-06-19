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
time zcat ${file} | while read l; do
    linemd5=$(echo "$l" | md5sum | awk '{print $1}')
    echo "$l"
    json=$(echo "$l"|sed 's/^[^{]*{/{/' |sed 's/\*/__ANY__/g' |sed 's/\:null/\:"null"/g' |sed 's/"\:"/ZzZzZ/g'| sed 's/","/XxXxX/g'| sed 's/"//g'| sed 's/ZzZzZ/":"/g'| sed 's/XxXxX/","/g'|sed 's/{/{"/'| sed 's/}$/"}/'|sed 's/"null"/null/g' |jq --arg filemd5 $filemd5  --arg linemd5 $linemd5 '. += {LOGFILE:$filemd5,id:$linemd5} | remove_empty') || die "not json"
    curl  -s -X POST -H 'Content-Type: application/json' \
    "http://${HOST}:8983/solr/${CORE}/update/json/docs" \
    --data-binary "${json}" > /dev/null || die 'solr error'
done
curl "http://${HOST}:8983/solr/${CORE}/update?commit=true"
log "done with $file"
