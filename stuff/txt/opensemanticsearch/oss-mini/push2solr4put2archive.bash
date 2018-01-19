#!/bin/bash
# push 2 solr
# move 2 archive
# param $1 directory to process

SOLR=""
ARCHIVEDIR="/tmp/archive"

log() { echo "$(date) $0: $*"; }
error() { echo "$(date) $0: $*" >&2; }
die() { error "$*"; exit 1; }

[ -d $ARCHIVEDIR ] || mkdir -p $ARCHIVEDIR || die "can not create $ARCHIVEDIR"
sleep 1
log "starting with $1"
cd $1
tmp=$(mktemp -d)
ls | grep -v meta.json | while read f; do
  md5=$(md5sum "$f"| cut -f1 -d" ")
  #TODO query solr first for md5
  # copy file and meta to tmp dir
  mkdir $tmp/$md5
  mv "$f" $tmp/$md5/
  cp meta.json $tmp/$md5/
  cd $tmp/$md5
  # index file
  etl-file $(pwd) |& while read m; do log $m; done
  # pack it up
  TMP=$(mktemp)
  # TODO if exists $ARCHIVEDIR/$md5.tar.xz
  tar -cv * | xz -9v -e > $ARCHIVEDIR/$md5.tar.xz 2> $TMP
  last=$?
  [ $last != 0 ] && die "xz error on $md5 $f $1 $(cat $TMP)"
  rm *
  cd ..
  rmdir $tmp/$md5
  cd $1
  log "archived  $f -> $tmp/$md5 -> $ARCHIVEDIR/$md5.tar.xz"
done || die "some errors above "
rm meta.json
cd ..
rmdir $1
log "done with $1"
