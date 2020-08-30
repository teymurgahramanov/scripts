#!/bin/bash

# $1 Path to CRL file

openssl crl -in $1 -noout > /dev/null 2>&1
if [ $? == 0 ]; then
        enddate=$(openssl crl -in $1 -nextupdate -noout | cut -d = -f2)
        enddate_s=$(date -d "${enddate}" +%s)
        now_s=$(date -d now +%s)
        enddate_m=$(( (enddate_s - now_s) / 60 ))
        echo "$enddate_m"
else
        enddate=$(openssl crl -inform DER -in $1 -nextupdate -noout | cut -d = -f2)
        enddate_s=$(date -d "${enddate}" +%s)
        now_s=$(date -d now +%s)
        enddate_m=$(( (enddate_s - now_s) / 60 ))
        echo "$enddate_m"
fi
