#!/bin/bash

# monitors directory for subsdirectories meta.json close_write
# and start process script
# also on start procces old existing ones

DEFAULTS="/etc/default/upload-directory-monitor"

log() { echo "$(date) $0: $*"; }
error() { echo "$(date) $0: $*" >&2; }
die() { error "$*"; exit 1; }

XENIAL=$(lsb_release -c | cut -f2)
if [ "$XENIAL" != "xenial" ]; then
    error "sorry, tested only with xenial ;(";
fi

if [ ! -f "$DEFAULTS" ]; then
  die "$DEFAULTS not found! Please check the DEFAULTS setting in your $0 script."
fi
source "$DEFAULTS"

if [ ! -f "$PROCESS" ]; then
  die "PROCESS $PROCESS not found! "
fi

if [ ! -d "$UPLOADDIRECTORY" ]; then
  die "UPLOADDIRECTORY $UPLOADDIRECTORY not found! "
fi

log "starting $UPLOADDIRECTORY"

oldfiles=$(ls $UPLOADDIRECTORY| wc -l)
if [ $oldfiles -ne 0 ]
then
  log "old files $oldfiles"
  ls $UPLOADDIRECTORY/*/meta.json | while read meta
  do
    dir=$(dirname "$meta")
    log "start processing old $dir"
    nice $PROCESS "$dir" &
  done
fi

while read tmp
do
    log "got $tmp"
    echo "$tmp" | grep "meta.json" | while read meta
    do
      dir=$(echo "$meta"| cut -f1 -d" ")
      log "start processing new $dir"
      nice $PROCESS "$dir" &
    done
done < <(inotifywait -mr -e close_write "$UPLOADDIRECTORY")
