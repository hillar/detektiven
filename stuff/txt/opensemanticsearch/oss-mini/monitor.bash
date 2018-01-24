#!/bin/bash
# param $1 directory to monitor for file named meta.json

LOG="/tmp/monitor.log"
ERRORLOG="/tmp/monitor.error.log"
PROCESS="./push2solr4put2archive.bash"

echo "$(date) $0: starting $1"
echo "$(date) $0:files $(ls $1| wc -l)"
while read line
do
    echo "$line" | grep "meta\.json"| while read meta
    do
      dir=$(echo $meta| cut -f1 -d" ")
      echo "$(date) $0: launcing $meta"
      $PROCESS "$dir" &
    done
done < <(inotifywait -mr -e close_write "$1")
