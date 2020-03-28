#!/bin/bash

# $1 Server name (ex: google.com)
# $2 HTTPS Port

enddate=$(echo | openssl s_client -servername $1 -connect $1:$2 2>/dev/null | openssl x509 -noout -enddate | cut -d = -f2)
enddate_s=$(date -d "${enddate}" +%s)
now_s=$(date -d now +%s)
enddate_d=$(( (enddate_s - now_s) / 86400 ))
echo "$enddate_d"
