#!/bin/sh

declare -A SOURCES

SOURCES=(\
        ["CA_NAME_1"]="https://ca_url_1.com" \
        ["CA_NAME_2"]="https://ca_url_2.com" \
)

for K in "${!SOURCES[@]}";
do

        CRL_URL=${SOURCES[$K]}
        CRL_PATH="/etc/httpd/SSL/CRL"
        CRL_FILE="$CRL_PATH/$K.crl"
        CRL_STATUS_FILE="$CRL_PATH/$K.crl.status"

        wget -q -O /tmp/$K.crl "$CRL_URL"

        if [ $? -ne 0 ];
        then
                echo $date "wget error" >>  /tmp/crl.log
                exit 1
        fi

    	#Check if CRL updated
    	NEW_CRL_VERSION="$(openssl crl -inform der -in /tmp/$K.crl -crlnumber -noout | cut -d= -f2)"

    	#Check version of currently used CRL
    	if [ -f $CRL_STATUS_FILE ];
	then
                LAST_CRL_VERSION=$(cat $CRL_STATUS_FILE)
        else
                LAST_CRL_VERSION=0
        fi

		#If CRL updated, convert this new CRL to PEM and set permissions
        if [ "$NEW_CRL_VERSION" != "$LAST_CRL_VERSION" ];
        then
                echo $NEW_CRL_VERSION > $CRL_STATUS_FILE
                openssl crl -inform der -in /tmp/$K.crl > $CRL_FILE
                chown owneruser:ownergroup $CRL_FILE
                chmod 0640 $CRL_FILE
                restorecon $CRL_FILE
        fi

done

rm -f /tmp/*.crl
