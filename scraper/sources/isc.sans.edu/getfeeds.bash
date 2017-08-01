
echo "$1" 
zcat $1 |sed 1,1d | while read line; do
  name=$(echo $line| rev| cut -f1 -d,| rev| sed 's/"//g');
  lastupdate=$(echo $line| rev| cut -f3 -d,| rev| sed 's/"//g'); 
  lastupdate=$(date -d "$(echo $line| rev| cut -f3 -d,| rev| sed 's/"//g')" +%s)
  [ -d "$name" ] || mkdir $name
  [ -f "$name/$name.$lastupdate.csv.gz" ] || curl -s https://isc.sans.edu/api/threatlist/$name/?json | jq -r '(map(keys) | add | unique) as $cols | map(. as $row | $cols | map($row[.])) as $rows | $cols, $rows[] | @csv' | gzip -9 > $name/$name.$lastupdate.csv.gz
done
