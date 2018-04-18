#!/usr/bin/env bash
#
# get scripts to build detektiven
#

log() { echo "$(date) $0: $*"; }
die() { log ": $*" >&2; exit 1; }

TARGETDIR=$(pwd)
log "downloading detektiven"
cd /tmp
[ -f master.tar.gz ] && rm master.tar.gz
wget -q https://github.com/hillar/detektiven/archive/master.tar.gz
[ -f master.tar.gz ] || die 'failed to get detektiven source from https://github.com/hillar/detektiven'
log "unpacking detektiven"
tar -xzf master.tar.gz
[ -f detektiven-master/vagans/getup.bash ] || die 'ERROR - no getup.bash'
mkdir -p ${TARGETDIR}/detektiven/scripts
[ -d ${TARGETDIR}/detektiven/scripts ] || die "can not create directory ${TARGETDIR}/detektiven/scripts"
cp -r detektiven-master/vagans/* ${TARGETDIR}/detektiven/scripts
[ $? -ne 0 ] && die "failed to copy scripts to ${TARGETDIR}/detektiven/scripts"
rm master.tar.gz
#rm -rf detektiven-master
log "build scripts copied to ${TARGETDIR}/detektiven/scripts"
log "read ${TARGETDIR}/detektiven/scripts/getup.bash before you run it!"
cd ${TARGETDIR}/detektiven/scripts/
