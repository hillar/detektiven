echo "$1"
name="$1"
TIME=$(date +%s)
BEARER=$(./sign_jwt.bash nonce kk@kk "http://localhost:3000/api" pushnews 100 private.pem)
cd $name || exit
APIURL="http://localhost:3000/api/v0/fli/csv?feed=$name&time=$TIME&$name"

ll=$(ls *.csv.gz | tail -2)
if [ $(echo "$ll" | wc -l) -eq 2 ]; then
  zdiff $ll | grep ">"| sed 's/> //'  > $name.$TIME.news
  if [ $(cat $name.$TIME.news | wc -c) -gt 1 ]; then
    lf=$(echo "$ll"| tail -1)
    cat $name.$TIME.news| iconv -t ascii//TRANSLIT | curl -D $name.$TIME.headers -XPOST --compressed -H "Authorization: Bearer $BEARER" -H "Content-Type: text/csv; charset=us-ascii" $APIURL --data-binary @-
    echo "$? $APIURL"
    cat $name.$TIME.headers | grep HTTP/1.1 | grep -v 100
    rm $name.$TIME.*
  fi
fi
cd ..
