echo "$1"
name="$1"
TIME=$(date +%s)
cd $name || exit
APIURL="http://localhost:3000/api/v0/fli/csv"
BEARER="xxxxx.yyyy.zzz"
ll=$(ls *.csv.gz | tail -2)
if [ $(echo "$ll" | wc -l) -eq 2 ]; then
  zdiff $ll | grep ">"| sed 's/> //'  > $name.$TIME.news
  if [ $(cat $name.$TIME.news | wc -c) -gt 1 ]; then
    lf=$(echo "$ll"| tail -1)
    cat $name.$TIME.news| iconv -t ascii//TRANSLIT | curl -XPOST --compressed -H "Authorization: Bearer $BEARER" -H "Content-Type: text/csv; charset=us-ascii" $APIURL --data-binary @-
    rm $name.$TIME.news
  fi
fi
cd ..
