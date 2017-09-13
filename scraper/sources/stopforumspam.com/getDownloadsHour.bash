#!/bin/bash

# see https://www.stopforumspam.com/downloads

[ -f lastupdates.log ] || echo "$(date) initial start" > lastupdates.log
while true; do
  TIME=$(date +%s)
  #   	listed_ip_1_all.gz	listed_ip_1_ipv6_all.gz  	listed_email_1_all.gz  	listed_username_1_all.gz
  for name in ip ipv6 email username; do
    echo "$(date) $name" >> lastupdates.log
    curl -s -D $name.$TIME.headers "https://www.stopforumspam.com/downloads/listed_${name}_1_all.gz" --output $name.$TIME.gz
    ll=$(ls $name.*.gz | tail -2)
    if [ $(echo "$ll" | wc -l) -eq 2 ]; then
      zdiff $ll | grep ">"| sed 's/> //'  > $name.$TIME.news
       if [ $(cat $name.$TIME.news | wc -l) -gt 0 ]; then
         echo "$(date) $name $name.$TIME.news push $(cat $name.$TIME.news | wc -l)" >> lastupdates.log
       else
         echo "$name no news" >> lastupdates.log
         rm $name.$TIME.gz
       fi
    else
        echo "$name first run" >> lastupdates.log
    fi
  done
  sleep 3601
done
