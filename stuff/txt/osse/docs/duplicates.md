
# duplicates

## adding file with etl-file.bash

before adding new file, *local solr* is queried with this file md5 against existing *md5 field*

if not found, new doc is added

if found, existing doc is updated with *alias field*

*local solr* is variable in **etl-file.bash** script and by default is set to
```
SOLR="127.0.0.1:8983"
CORE="solrdefalutcore"
```
*md5 field* is variable in **etl-file.bash** script and by default is set to
```
MD5F="file_md5_s"
```

etl-file.bash script is created by *[etl/install-etl.bash](../etl/install-etl.bash#L119)* script

// TODO  aliases is hardcoded, make it param

cmd
```
etl-file /tmp/singlespace
Wed Mar 21 06:29:11 UTC 2018 /usr/local/bin/etl-file: adding d784fa8b6d98d27699781bd9a7cf19f0 /tmp/singlespace
```
result doc in solr

```json
{
  "responseHeader":{
    "status":0,
    "QTime":1,
    "params":{
      "q":"singlespace",
      "_":"1521613408773"}},
  "response":{"numFound":1,"start":0,"docs":[
      {
        "etl_enhance_regex_b":true,
        "id":"file:///tmp/singlespace",
        "etl_enhance_file_meta_b":true,
        "etl_enhance_file_mtime_b":true,
        "etl_enhance_mapping_id_b":true,
        "content_type_group":["Text document"],
        "etl_enhance_contenttype_group_b":true,
        "content_type":["text/plain; charset=ISO-8859-1"],
        "etl_enhance_ocr_descew_b":true,
        "etl_enhance_file_md5_b":true,
        "etl_filter_blacklist_b":true,
        "etl_enhance_zip_b":true,
        "etl_clean_title_b":true,
        "etl_enhance_pst_b":true,
        "file_md5_s":"d784fa8b6d98d27699781bd9a7cf19f0",
        "etl_enhance_extract_text_tika_server_b":true,
        "encoding_s":"ISO-8859-1",
        "file_modified_dt":"2018-03-21T06:29:01Z",
        "title":["singlespace"],
        "etl_enhance_pdf_ocr_b":true,
        "_version_":1595527661933821952}]
  }}
```

adding same content with different filename

```
etl-file /tmp/singlespace2
Wed Mar 21 06:30:18 UTC 2018 /usr/local/bin/etl-file: added alias d784fa8b6d98d27699781bd9a7cf19f0 "file:///tmp/singlespace" /tmp/singlespace2
```

original is updated by adding **aliases**

```
..
        "aliases":["/tmp/singlespace2"],
..
```
full updated doc

```json
{
  "responseHeader":{
    "status":0,
    "QTime":1,
    "params":{
      "q":"singlespace",
      "_":"1521613408773"}},
  "response":{"numFound":1,"start":0,"docs":[
      {
        "etl_enhance_regex_b":true,
        "id":"file:///tmp/singlespace",
        "etl_enhance_file_meta_b":true,
        "etl_enhance_file_mtime_b":true,
        "etl_enhance_mapping_id_b":true,
        "content_type_group":["Text document"],
        "etl_enhance_contenttype_group_b":true,
        "content_type":["text/plain; charset=ISO-8859-1"],
        "etl_enhance_ocr_descew_b":true,
        "etl_enhance_file_md5_b":true,
        "etl_filter_blacklist_b":true,
        "etl_enhance_zip_b":true,
        "etl_clean_title_b":true,
        "etl_enhance_pst_b":true,
        "file_md5_s":"d784fa8b6d98d27699781bd9a7cf19f0",
        "etl_enhance_extract_text_tika_server_b":true,
        "encoding_s":"ISO-8859-1",
        "file_modified_dt":"2018-03-21T06:29:01Z",
        "title":["singlespace"],
        "etl_enhance_pdf_ocr_b":true,
        "aliases":["/tmp/singlespace2"],
        "_version_":1595527730787516416}]
  }}
```

same content and same name is not added

```
root@osse-singlebox:/opt/etl/python# etl-file /tmp/singlespace
Wed Mar 21 06:32:06 UTC 2018 /usr/local/bin/etl-file: file already indexed d784fa8b6d98d27699781bd9a7cf19f0 /tmp/singlespace 2

root@osse-singlebox:/opt/etl/python# etl-file /tmp/singlespace2
Wed Mar 21 06:32:08 UTC 2018 /usr/local/bin/etl-file: file already indexed d784fa8b6d98d27699781bd9a7cf19f0 /tmp/singlespace2 1
```

## adding file to file-server

no check are done

duplicates are handled by etl-file.bash

//TODO ? do something like in fileserver

sample cmd
```
file=/tmp/singlespace; \
curl -k -s -X POST \
-F "file=@$file" \
-H "Content-Type: multipart/form-data" \
http://127.0.0.1:8125
```
tail /var/log/osse-fileserver-monitor/news-17050.log
```
Wed Mar 21 06:05:35 UTC 2018 starting /opt/osse-fileserver/bin/osse-fileserver-news-monitor.bash pid 17050 /var/data/osse-fileserver/osse-singlebox
Wed Mar 21 07:15:33 UTC 2018 /opt/osse-fileserver/bin/osse-fileserver-news-monitor.bash pid 17050 new files in ./f317dd49-f773-7329-4752-877662e4d0ff/
Wed Mar 21 07:15:33 UTC 2018 /usr/local/bin/etl-file: adding 7c90bac9c326cbe92ffefa4f4c8315e6 ./f317dd49-f773-7329-4752-877662e4d0ff//singlespace.xz
Wed Mar 21 07:27:47 UTC 2018 /opt/osse-fileserver/bin/osse-fileserver-news-monitor.bash pid 17050 new files in ./efc0b918-30d0-bdd8-6690-060789fcdda7/
Wed Mar 21 07:27:48 UTC 2018 /usr/local/bin/etl-file: added meta 7c90bac9c326cbe92ffefa4f4c8315e6 ./efc0b918-30d0-bdd8-6690-060789fcdda7//singlespace.xz
Wed Mar 21 07:27:48 UTC 2018 /usr/local/bin/etl-file: added alias 7c90bac9c326cbe92ffefa4f4c8315e6 "./f317dd49-f773-7329-4752-877662e4d0ff//singlespace.xz" ./efc0b918-30d0-bdd8-6690-060789fcdda7//singlespace.xz
Wed Mar 21 07:28:56 UTC 2018 /opt/osse-fileserver/bin/osse-fileserver-news-monitor.bash pid 17050 new files in ./8c7777b2-9fbc-9c99-91e4-aeb9f484fab7/
Wed Mar 21 07:28:56 UTC 2018 /usr/local/bin/etl-file: added meta 7c90bac9c326cbe92ffefa4f4c8315e6 ./8c7777b2-9fbc-9c99-91e4-aeb9f484fab7//singlespace.xz
Wed Mar 21 07:28:56 UTC 2018 /usr/local/bin/etl-file: added alias 7c90bac9c326cbe92ffefa4f4c8315e6 "./f317dd49-f773-7329-4752-877662e4d0ff//singlespace.xz" ./8c7777b2-9fbc-9c99-91e4-aeb9f484fab7//singlespace.xz
```

## adding file with osse-server

on upload file md5 is calculated [on the fly]()

**all *index servers*** are queried against existing *md5 field*

if not found, md5 is added to meta data and file is sent to file-server

if found, noop

*md5 field* is defined in config file

 ```
 # grep md5 /opt/osse-server/conf/config.json

   "md5Fieldname":"file_md5_s"

 ```

 config file is created by [osse/install-osse.bash](../osse/server/install-osse.bash#L29) script


 sample cmd
```
 file=/tmp/singlespace; \
 curl -k -i -X POST \
 -F "file=@$file" \
 -H "Content-Type: multipart/form-data" \
 -uuploadonly:uploadonly http://192.168.11.2/files
```

tail /var/log/osse-server/osse-server.log
```
{"time":"2018-03-21T07:33:11.867Z","notice":{"ip":"192.168.11.2","username":"uploadonly","access":{"route":"POST/files","urlPath":"/files","args":{}}}}
{"time":"2018-03-21T07:33:11.967Z","notice":{"ip":"192.168.11.2","username":"uploadonly","uploadExist":{"md5":"d784fa8b6d98d27699781bd9a7cf19f0","filename":"singlespace","id":"file:///tmp/singlespace","server":"hardCodedDefault","saveTo":"/var/data/osse-server/spool/ac27a754-d4af-e506-f618-72ec53f36da5.tmp"}}}
```
