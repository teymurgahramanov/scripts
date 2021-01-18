#!/bin/sh

#Usage: crl_rotator.sh source1 source2 source3 ... group_name

#Note:
#You can define as many sources as you want and can provide any sources as argument.
#CRLs will be downloaded and combined in order in which you will provide them as arguments
#Last argument always will be used as group name

SOFTWARE=haproxy
CRL_OWNER_USER=haproxy 
CRL_OWNER_GROUP=haproxy
CRL_GROUP="${@: -1}"
CRL_DIR="/etc/haproxy/ssl/crl" 
CRL_INFO_FILE="$CRL_DIR"/info.txt # for errors 

echo -n > $CRL_INFO_FILE

declare -A SOURCES=( \
	["bsxm_azroot"]="http://asxm.e-imza.az/cdp/AZ%20Root%20Authority%20(RCA).crl" \
	["bsxm_azpolicy"]="http://asxm.e-imza.az/cdp/AZ%20Policy%20Authority%20(PCA).crl" \
	["bsxm_ca"]="http://bsxm.cbar.az/crl/armbbsxm.crl" \
	)

ARGUMENTS=("$@")

for A in "${!ARGUMENTS[@]}";
do

if [ "${ARGUMENTS[$A]}" != "$CRL_GROUP" ]; then
	
	CRL_URL=${SOURCES[${ARGUMENTS[$A]}]}
	CRL_FILE="$CRL_DIR/${ARGUMENTS[$A]}.crl"
	CRL_STATUS_FILE="$CRL_DIR"/"${ARGUMENTS[$A]}".crl.status
	CRL_COMBO_FILE="$CRL_DIR"/"$CRL_GROUP"_combo.crl
	TMP_CRL_FILE=/tmp/${ARGUMENTS[$A]}.crl
	TMP_CRL_COMBO_FILE=/tmp/"$CRL_GROUP"_combo.crl

	if [ ! -d $CRL_DIR ]; then
		echo "No such path $CRL_DIR"
		exit 1
	fi

	curl "$CRL_URL" --output $TMP_CRL_FILE --silent
	if [ $? == 0 ]; then
		#Check if CRL in PEM format
		openssl crl -in $TMP_CRL_FILE -noout > /dev/null 2>&1
		if [ $? == 0 ]; then
			#Compare CRL versions to ensure that downloaded is newer
			NEW_CRL_VERSION="$(openssl crl -in $TMP_CRL_FILE -crlnumber -noout | cut -d= -f2)"
			if [ -f $CRL_STATUS_FILE ]; then
				LAST_CRL_VERSION=$(cat $CRL_STATUS_FILE)
			else
				LAST_CRL_VERSION=0
			fi
			if [ "$NEW_CRL_VERSION" != "$LAST_CRL_VERSION" ]; then
				echo $NEW_CRL_VERSION > $CRL_STATUS_FILE
				openssl crl -in $TMP_CRL_FILE > $CRL_FILE
				chown $CRL_OWNER_USER:$CRL_OWNER_GROUP $CRL_FILE
				chmod 0640 $CRL_FILE
				restorecon $CRL_FILE
			fi
		#In case if CRL in DER format
		else
			NEW_CRL_VERSION="$(openssl crl -inform der -in $TMP_CRL_FILE -crlnumber -noout | cut -d= -f2)"
			if [ -f $CRL_STATUS_FILE ]; then
				LAST_CRL_VERSION=$(cat $CRL_STATUS_FILE)
			else
				LAST_CRL_VERSION=0
			fi
			if [ "$NEW_CRL_VERSION" != "$LAST_CRL_VERSION" ]; then
				echo $NEW_CRL_VERSION > $CRL_STATUS_FILE
				#Convert DER to PEM
				openssl crl -inform der -in $TMP_CRL_FILE > $CRL_FILE
				chown $CRL_OWNER_USER:$CRL_OWNER_GROUP $CRL_FILE
				chmod 0640 $CRL_FILE
				restorecon $CRL_FILE	
			fi
		fi
	else
		echo "$(date +"%D %T") Something went wrong with $CRL_FILE" >> $CRL_INFO_FILE
	fi
	
	if [ -f $CRL_FILE ]; then
		cat $CRL_FILE >> $TMP_CRL_COMBO_FILE
	elif [ ! -f $CRL_FILE ]; then
		echo "$(date +"%D %T") Couldnt find $CRL_FILE" >> $CRL_INFO_FILE
	fi
fi
done

if [[ -f "$CRL_COMBO_FILE" ]]; then
HASH_OLD=$(md5sum $CRL_COMBO_FILE  | cut -d " " -f 1)
HASH_NEW=$(md5sum $TMP_CRL_COMBO_FILE | cut -d " " -f 1)
	if [[ $HASH_NEW == $HASH_OLD ]]; then
		rm -f $TMP_CRL_COMBO_FILE
	elif [[ $HASH_NEW != $HASH_OLD ]]; then
		mv -f $TMP_CRL_COMBO_FILE $CRL_COMBO_FILE
		chown $CRL_OWNER_USER:$CRL_OWNER_GROUP $CRL_COMBO_FILE
        	chmod 0640 $CRL_COMBO_FILE
        	restorecon $CRL_COMBO_FILE
		systemctl reload $SOFTWARE
	fi
else
	mv -f $TMP_CRL_COMBO_FILE $CRL_COMBO_FILE
    	chown $CRL_OWNER_USER:$CRL_OWNER_GROUP $CRL_COMBO_FILE
    	chmod 0640 $CRL_COMBO_FILE
    	restorecon $CRL_COMBO_FILE
    	systemctl reload $SOFTWARE
fi

rm -f /tmp/*.crl
