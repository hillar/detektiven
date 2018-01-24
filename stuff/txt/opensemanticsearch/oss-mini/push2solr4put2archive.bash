#!/bin/bash
# 1 push 2 solr
# 2 check subscriptions
# 3 move 2 archive
# param $1 directory to process

SOLR="127.0.0.1:8983"
ARCHIVEDIR="/tmp/archive"
SUBSDIR="/var/spool/oss-mini/subscriptions/"
SENDMAIL="./just-send-mail.bash"

log() { echo "$(date) $0: $*"; }
error() { echo "$(date) $0: $*" >&2; }
die() { error "$*"; exit 1; }

[ -d $1 ] || die "does not exist $1"
[ -d $ARCHIVEDIR ] || mkdir -p $ARCHIVEDIR || die "can not create $ARCHIVEDIR"
sleep 1
log "starting with $1"
cd $1
tmp=$(mktemp -d)
ls | grep -v meta.json | while read f; do
  md5=$(md5sum "$f"| cut -f1 -d" ")
  log "file $md5 $f"
  # copy file and meta to tmp dir
  mkdir $tmp/$md5
  mv "$f" $tmp/$md5/
  cp meta.json $tmp/$md5/
  cd $tmp/$md5
  # push 2 solr
  ## query solr first for md5
  existsTMP=$(mktemp)
  curl -s "http://$SOLR/solr/core1/select?fl=id&wt=json&q=$md5" > $existsTMP
  last=$?
  [ $last != 0 ] && die "solr error $md5 $f $1"
  if [ $(cat $existsTMP | jq .response.docs[].id | grep -v "meta.json" | wc -l) -le 1 ]
  then
    etl-file $(pwd) |& while read m; do log $m; done
    # check subscriptions
    ## create filter list
    SUBSTMP=$(mktemp)
    cat $SUBSDIR/*/subscriptions.json | jq .fields.strings | while read subs
    do
      echo "$subs" |sed 's/"//g'| sed 's/,/\n/g'
    done | sort | uniq > $SUBSTMP
    ## query each filter
    found=$(mktemp -d)
    cat $SUBSTMP | while read query
    do
        log "quering $query $md5"
        fTMP=$(mktemp)
        json="{query:\"$query\",filter:\"id:*/$md5/*\"}"
        curl -s "http://$SOLR/solr/core1/query?fl=id" -d $json > $fTMP
        #curl -s "http://$SOLR/solr/core1/select?fl=id&wt=json&q=$md5" > $fTMP
        cat $fTMP | jq .response.numFound
        if [ $(cat $fTMP | jq .response.numFound) -gt 0 ]
        then
            log "found $query in $md5"
            echo $query >> $found/$md5
        fi
        rm $fTMP
    done
    rm $SUBSTMP
    ## for each matched filter send mail
    ls $found | while read m5
    do
      cat $found/$m5 | while read q
      do
          ls $SUBSDIR | while read name
          do
            if [ $(cat $SUBSDIR/$name/subscriptions.json | jq .fields.strings | grep "$q" | wc -l) -gt 0 ]
            then
              log "subscription $name $q"
              cat $SUBSDIR/$name/subscriptions.json | jq .emails | grep @ | sed 's/,//'| while read to
              do
                  log "sending mail to $name $to on $md5 $q"
                  $SENDMAIL $to "$(date) match found" "$md5"
              done
            fi
          done
      done
    done
    rm -rf $found
    # move 2 archive
    TMP=$(mktemp)
    # TODO if exists $ARCHIVEDIR/$md5.tar.xz
    tar -cv * | xz -9v -e > $ARCHIVEDIR/$md5.tar.xz 2> $TMP
    last=$?
    [ $last != 0 ] && die "xz error on $md5 $f $1 $(cat $TMP)"
    log "archived  $f -> $tmp/$md5 -> $ARCHIVEDIR/$md5.tar.xz"
  else
    log "index exists $f $(cat $existsTMP| jq .response.docs[].id| grep -v "meta.json")"
  fi
  rm $existsTMP
  rm *
  cd ..
  rmdir $tmp/$md5
  cd $1
done || die "some errors above "
rm meta.json
cd ..
rmdir $1
log "done with $1"
