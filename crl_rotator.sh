#!/bin/sh

declare -A SOURCES

OWNER_USER=apache
OWNER_GROUP=apache

declare -A SOURCES=(["CRL_SOURCE_1_NAME"]="CRL_SOURCE_1_URL")

for K in "${!SOURCES[@]}";
do

        CRL_URL=${SOURCES[$K]}
        CRL_PATH="/PATH/TO/CRL/DIRECTORY"
        CRL_FILE="$CRL_PATH/$K.crl"
        CRL_STATUS_FILE="$CRL_PATH/$K.crl.status"

        wget -q -O /tmp/$K.crl "$CRL_URL"
        if [ $? == 0 ];
        then
                #Check if CRL in PEM format
                openssl crl -in /tmp/$K.crl -noout > /dev/null 2>&1
                if [ $? == 0 ];
                then
                        #Compare CRL versions to ensure that downloaded is newer
                        NEW_CRL_VERSION="$(openssl crl -in /tmp/$K.crl -crlnumber -noout | cut -d= -f2)"
                        if [ -f $CRL_STATUS_FILE ];
                        then
                                LAST_CRL_VERSION=$(cat $CRL_STATUS_FILE)
                        else
                        LAST_CRL_VERSION=0
                        fi
                        if [ "$NEW_CRL_VERSION" != "$LAST_CRL_VERSION" ];
                        then
                        echo $NEW_CRL_VERSION > $CRL_STATUS_FILE
                        openssl crl -in /tmp/$K.crl > $CRL_FILE
                        chown $OWNER_USER:$OWNER_GROUP $CRL_FILE
                        chmod 0640 $CRL_FILE
                        restorecon $CRL_FILE
                        fi
                #In case if CRL in DER format
                else
                        NEW_CRL_VERSION="$(openssl crl -inform der -in /tmp/$K.crl -crlnumber -noout | cut -d= -f2)"
                        if [ -f $CRL_STATUS_FILE ];
                        then
                                LAST_CRL_VERSION=$(cat $CRL_STATUS_FILE)
                        else
                                LAST_CRL_VERSION=0
                        fi
                        if [ "$NEW_CRL_VERSION" != "$LAST_CRL_VERSION" ];
                        then
                        echo $NEW_CRL_VERSION > $CRL_STATUS_FILE
                        #Convert DER to PEM
                        openssl crl -inform der -in /tmp/$K.crl > $CRL_FILE
                        chown $OWNER_USER:$OWNER_GROUP $CRL_FILE
                        chmod 0640 $CRL_FILE
                        restorecon $CRL_FILE
                        fi
                fi
        else
                echo "$(date +"%D %T") Unable to download $K.crl" >> /tmp/crl_rotator.log
        fi
done

rm -f /tmp/*.crl
