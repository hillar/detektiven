#!/usr/bin/env bash
#
# get scripts to build detektiven
#

log() { echo "$(date) $0: $*"; }
die() { log ": $*" >&2; exit 1; }

PWD=$(pwd)
cd /tmp
[ -f master.tar.gz ] && rm master.tar.gz
wget -q https://github.com/hillar/detektiven/archive/master.tar.gz
[ -f master.tar.gz ] || die 'failed to get detektiven source from https://github.com/hillar/detektiven'
tar -xzf master.tar.gz
[ -f detektiven-master/vagans/getup.bash ] || die 'ERROR - no getup.bash'
mkdir -p ${PWD}/detektiven/scripts
[ -d ${PWD}/detektiven/scripts ] || die "can not create directory ${PWD}/detektiven/scripts"
cp -r detektiven-master/vagans/* ${PWD}/detektiven/scripts
[ $? -ne 0 ] && die "failed to copy scripts to ${PWD}/detektiven/scripts"
rm master.tar.gz
#rm -rf detektiven-master
log "build scripts copied to ${PWD}/detektiven/scripts"
log "read ${PWD}/detektiven/scripts/getup.bash before you run it!"
