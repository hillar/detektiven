#!/usr/bin/env bash
#
# get scripts to build detektiven
#

log() { echo "$(date) $0: $*"; }
die() { log ": $*" >&2; exit 1; }

TARGETDIR=$(pwd)
# check if we are running from detektiven/scripts
# if yes, die
tmp1=$(basename ${TARGETDIR})
tmp2=$(basename $(dirname ${TARGETDIR}))
[ "${tmp1}" = "scripts" -a "${tmp2}" = "detektiven" ] && die "already copied here ${TARGETDIR}"
# check if exits already
[ -f ${TARGETDIR}/detektiven/scripts/getup.bash ] && die "already copied to ${TARGETDIR}/detektiven/scripts"
TMP=$(mktemp -d)
cd ${TMP}
wget -q https://github.com/hillar/detektiven/archive/master.tar.gz
[ -f master.tar.gz ] || die 'failed to get detektiven source from https://github.com/hillar/detektiven'
log "unpacking detektiven"
tar -xzf master.tar.gz
[ -f detektiven-master/vagans/getup.bash ] || die 'ERROR - no getup.bash'
mkdir -p ${TARGETDIR}/detektiven
[ -d ${TARGETDIR}/detektiven ] || die "can not create directory ${TARGETDIR}/detektiven"
mv detektiven-master/vagans detektiven-master/scripts
cp -r detektiven-master/scripts ${TARGETDIR}/detektiven
[ $? -ne 0 ] && die "failed to copy scripts to ${TARGETDIR}/detektiven/scripts"
rm -rf ${TMP}
rm ${TARGETDIR}/detektiven/scripts/getit.bash
log "build scripts copied to ${TARGETDIR}/detektiven/scripts"
log "read ${TARGETDIR}/detektiven/scripts/getup.bash before you run it!"
cd ${TARGETDIR}/detektiven/scripts/
