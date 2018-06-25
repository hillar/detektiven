#!/bin/bash

log() { echo "$(date) $0: $*"; }
die() { log "$*" >&2; exit 1; }

gzip --version &> /dev/null || die 'no gzip'
xz --version &> /dev/null || die 'no xz'
nodejs --version &> /dev/null || die 'no nodejs'
[ -f parse-json.js ] || die 'missing parse-json.js'
[ -f parse-csv.js ] || die 'missing parse-csv.js'

spool=$1
[ -z ${spool} ] && die "no spool dir"
[ -d ${spool} ] || die "spool dir does not exists"
archive=$2
[ -z ${archive} ] && die "no archive dir"
[ -d ${archive} ] || mkdir -p ${archive}
[ -d ${archive} ] || die "can not create archive dir ${archive}"

ls ${spool}/*.gz 2> /dev/null | while read file;
do
  filemd5=$(md5sum "${file}" | awk '{print $1}')
  fn=$(basename "${file}")
  if [ -f ${archive}/${fn}.${filemd5}.xz ]; then
    log "WARNING xz exists, skipping ${file}"
  else
    log "starting ${fn}"
    if echo "$file"|grep "csv"; then
      nodejs parse-csv.js --file "${file}" || die "can not parse $fn"
    else
      nodejs parse-json.js --file "${file}" || die "can not parse $fn"
    fi
    zcat ${file} | xz -9 > ${archive}/${fn}.${filemd5}.xz || die "can not xz $fn"
    rm -f ${file}
    log "done ${file}"
  fi
done
