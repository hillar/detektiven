echo "$1"
name="$1"
TIME=$(date +%s)
cd $name || exit
APIURL="https://localhost/api/v0/first_last_ip"
BEARER="xxxxx.yyyy.zzz"
ll=$(ls *.csv.gz | tail -2)
if [ $(echo "$ll" | wc -l) -eq 2 ]; then
  zdiff $ll | grep ">"| sed 's/> //'| sed 's/"//g' | jq -c -j -R -r 'split("\n") | map(split(",")) | map({"firstseen":.[0],"lastseen":.[2],"ip":.[1]})'> $name.$TIME.news
  [ $(cat $name.$TIME.news | wc -l) -gt 1 ] || exit
  cat $name.meta.json >> $name.$TIME.news
  echo "curl -XPOST --compressed -H "Authorization: Bearer $BEARER" -H "Content-Type: application/x-ndjson" $APIURL --data @$name.$TIME.news"
fi
cd ..
