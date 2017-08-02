[ -f lastupdates.log ] || echo "0" > lastupdates.log
while true; do
  TIME=$(date +%s)
  curl -s https://isc.sans.edu/api/threatfeeds/?json | jq -r '(map(keys) | add | unique) as $cols | map(. as $row | $cols | map($row[.])) as $rows | $cols, $rows[] | @csv'| gzip -9 > threatfeeds.$TIME.csv.gz
  echo "$(zcat threatfeeds.$TIME.csv.gz | cut -f4 -d,| sort| uniq| tail -2 | head -1)" >> lastupdates.log
  if [ ! $(tail -2 lastupdates.log | sort|uniq| wc -l) -eq 1 ]; then
    ./getthreatlistX.bash threatfeeds.$TIME.csv.gz
  else
    rm threatfeeds.$TIME.csv.gz
  fi
  sleep 61
done
