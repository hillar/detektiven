true as $doHeaders
| . / "\n"
| map(. / ";")
| (if $doHeaders then .[0] else [range(0; (.[0] | length)) | tostring] end) as $headers
| .[if $doHeaders then 1 else 0 end:][]
| . as $values
| keys
| map({($headers[.]): $values[.]})
| add
