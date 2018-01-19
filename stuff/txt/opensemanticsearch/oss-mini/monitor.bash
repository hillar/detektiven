#!/bin/bash
# param $1 directory to monitor for file named meta.json

while read line
do
    echo "close_write: $line"
    echo "$line" | grep "meta\.json"| while read meta
    do
      dir=$(echo $meta| cut -f1 -d" ")
      echo "launcing $meta"
      bash push2solr4put2archive.bash "$dir" &
    done
done < <(inotifywait -mr -e close_write "$1")
