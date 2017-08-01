
echo "$1"
threatfeedscsvgz="$1"
zcat $threatfeedscsvgz |sed 1,1d | while read line; do
  name=$(echo $line| rev| cut -f1 -d,| rev| sed 's/"//g');
  lastupdate=$(date -d "$(echo $line| rev| cut -f3 -d,| rev| sed 's/"//g')" +%s)
  [ -d "$name" ] || mkdir $name
  if [ -f "$name/$name.$lastupdate.csv.gz" ]; then
    curl -s https://isc.sans.edu/api/threatlist/$name/?json | jq -r '(map(keys) | add | unique) as $cols | map(. as $row | $cols | map($row[.])) as $rows | $cols, $rows[] | @csv' | gzip -9 > $name/$name.$lastupdate.csv.gz
    ./pushnews.bash "$name"
  fi
done
