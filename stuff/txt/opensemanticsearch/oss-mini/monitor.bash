#!/bin/bash
# param $1 directory to monitor for file named meta.json

LOG="/tmp/monitor.log"
ERRORLOG="/tmp/monitor.error.log"
PROCESS="bash push2solr4put2archive.bash"

echo "$(date) $0: starting $1" >>$LOG
echo "$(date) $0:files $(ls $1| wc -l)" >>$LOG
while read line
do
    echo "$line" | grep "meta\.json"| while read meta
    do
      dir=$(echo $meta| cut -f1 -d" ")
      echo "$(date) $0: launcing $meta" >>$LOG
      $PROCESS "$dir" >>$LOG 2>>$ERRORLOG &
    done
done < <(inotifywait -mr -e close_write "$1")
