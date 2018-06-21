#!/bin/bash
#
# sends osse-server subscriptions emails
# reads conf from osse-server config.json
#
# add to crontab, sample:
# */15 * * * * /opt/osse-server/bin/check-osse-subscriptions.bash /opt/osse-server/conf/config.json 1>> /var/log/osse-server/subscriptions.log 2>> /var/log/osse-server/subscriptions.error
#
# TODO: add support for elastic

SUBJ='HITS'

log() { echo "$(date) $(basename $0): $*"; }
die() { log "$*" >&2; exit 1; }
mail() {
  log " sending mail $1 $2 $3 $4 $5 "
  echo "ehlo $1"
  echo "MAIL FROM: <$2>"
  echo "RCPT TO: <$3>"
  echo "DATA"
  echo "From: <$2>"
  echo "To: <$3>"
  echo "Subject: $4"
  echo "$5"
  echo "."
  echo "quit"
}

curl --help > /dev/null || die "no curl"
jq --help > /dev/null || die "no jq"
nc --help > /dev/null || die "no nc"

[ -z $1 ] && die "no conf file"
[ -z $1 ] || CONFIGFILE=$1
[ -f ${CONFIGFILE} ] || die "can not read config ${CONFIGFILE}"
SMTPSERVER=$(cat ${CONFIGFILE} | jq -r .smtphost) || die "no smtphost in conf file ${CONFIGFILE}"
SMTPPORT=$(cat ${CONFIGFILE} | jq -r .smtpport) || die "no smtpport in conf file ${CONFIGFILE}"
FROM=$(cat ${CONFIGFILE} | jq -r .smtpfrom) || die "no smtpfrom in conf file ${CONFIGFILE}"
SUBSDIR=$(cat ${CONFIGFILE} | jq -r .subscriptionsDirectory) ||  die "no subscriptionsDirectory in conf file ${CONFIGFILE}"
SUBSFILE=$(cat ${CONFIGFILE} | jq -r .subscriptionsFilename) ||  die "no subscriptionsFilename in conf file ${CONFIGFILE}"
[ -d ${SUBSDIR} ] || die "no subs dir ${SUBSDIR}"

cd ${SUBSDIR}
ls -p | grep "/" | while read user
do
  [ -f ${user}/${SUBSFILE} ] || die "no subs file for ${user}"
  since=$(date -r ${user}/${SUBSFILE} +%s)
  q=$(cat ${user}/${SUBSFILE} | jq -r .fields.strings)
  [ -z ${q} ] && die "no query for ${user}"
  to=$(cat ${user}/${SUBSFILE} | jq -r .emails)
  [ -z ${to} ] && die "no email for ${user}"
  cat ${CONFIGFILE} | jq -r -c '.servers[]| "\(.proto)://\(.host):\(.port)/\(.type)/\(.collection)"'| while read server
  do
    if [ $? -ne 0 ]; then
      die "no server $server"
    else
      if LASTINDEX=$(date -d $(curl -s ${server}/admin/luke | jq -r .index.lastModified) +%s 2>/dev/null) ; then
        #log "LASTINDEX: $(date -d @${LASTINDEX}) ${server}"
        smd5=$(echo "${server}" | md5sum | cut -f1 -d" ")
        if [ -f ${user}/last.${smd5} ]; then
          SUBSTIME=$(date -r ${user}/last.${smd5} +%s)
          if [ ${LASTINDEX} -gt ${SUBSTIME} ]; then
            lastnf=$(cat ${user}/last.${smd5} )
            nf=$(curl -s "${server}/select?wt=json&rows=0&q=${q}"| jq .response.numFound)
            if [ ${nf} -ne ${lastnf} ]; then
              echo "${nf}" > ${user}/last.${smd5}
              log "use: ${user} email: ${to} query:${q} last: ${lastnf} current:${nf} since: $(date -d @${since})"
              mail ${SMTPSERVER} ${FROM} ${to} "${SUBJ}" "sub ${smd5} new hits $((nf-lastnf)) $(date -d @${LASTINDEX})"| nc ${SMTPSERVER} ${SMTPPORT} > /dev/null || die "failed to mail ${SMTPSERVER} ${SMTPPORT} ${to}"
            fi
          fi
        else
          nf=$(curl -s "${server}/select?wt=json&rows=0&q=${q}"| jq .response.numFound)
          echo "${nf}" > ${user}/last.${smd5}
          mail ${SMTPSERVER} ${FROM} ${to} "${SUBJ}" "sub ${smd5} started $nf"| nc ${SMTPSERVER} ${SMTPPORT} > /dev/null|| die "failed to mail ${SMTPSERVER} ${SMTPPORT} ${to}"
        fi
      else
       log "failed connect $server"
      fi
    fi
  done
done
