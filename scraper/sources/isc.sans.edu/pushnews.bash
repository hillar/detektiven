echo "$1"
name="$1"
TIME=$(date +%s)
cd $name || exit
ll=$(ls *.csv.gz | tail -2)
if [ $(echo "$ll" | wc -l) -eq 2 ]; then
  zdiff $ll | grep ">"| sed 's/> //'| sed 's/""//g' | jq -c -j -R -r 'split("\n") | map(split(",")) | map({"firstseen":.[0],"lastseen":.[2],"ip":.[1]})'> $name.$TIME.news
  [ $(cat $name.$TIME.news | wc -l) -gt 1 ] || exit
  cat $name.meta.json >> $name.$TIME.news
    echo "curl -XPOST --compressed -H "Authorization: Token xxxxxxxxxxxxxx" -H "Content-Type: application/x-ndjson" http://localhost:1234/api/v0/first_ip_last --data @$name.$TIME.news"
fi
cd ..
