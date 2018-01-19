#!/bin/bash
# push 2 solr
# move 2 archive
# param $1 directory to process

SOLR=""
ARCHIVEDIR="/tmp/archive"
[ -d $ARCHIVEDIR ] || mkdir -p $ARCHIVEDIR
sleep 2
cd $1
tmp=$(mktemp -d)
ls | grep -v meta.json | while read f; do
  md5=$(md5sum "$f"| cut -f1 -d" ")
  mkdir $tmp/$md5
  mv "$f" $tmp/$md5/
  #file "$tmp/$md5/$f"
  cp meta.json $tmp/$md5/
  cd $tmp/$md5
  pwd
  # TODO if exists $ARCHIVEDIR/$md5.tar.xz
  etl-file --verbose $(pwd)
  tar -cv * | xz -9v > $ARCHIVEDIR/$md5.tar.xz
  tar -cv * | gzip -9 > $ARCHIVEDIR/$md5.tar.gz
  rm *
  cd ..
  rmdir $tmp/$md5
  cd $1
  pwd


  echo "archived  $f -> $tmp/$md5 -> $ARCHIVEDIR/$md5.tar.xz"
  ls $ARCHIVEDIR/$md5.tar.xz
done
rm meta.json
cd ..
rmdir $1
echo "done with $1"
