### Script for rotating logs of multiple Application instances on multiple servers

ARRAY_APP=($(ls -l /App | grep -v total | awk -F " " '{print $9}'))
PATTERN=*.log.*
GET_DATE_LAST_MODIFIED="stat -c %y"
COMPRESSION="gzip -9 --suffix .z"

for i in ${!ARRAY_APP[@]};
do
        DIR_LOG=/Log/${ARRAY_APP[$i]}
        DIR_LOG_BACKUP=/mnt/LOGBACKUP/${ARRAY_APP[$i]}/$(hostname)

                find $DIR_LOG -mindepth 1 -type f ! -name '*.log' -mtime +30 -delete
                find $DIR_LOG -mindepth 1 -empty -type d -delete

                find $DIR_LOG -maxdepth 1 -type f -name "$PATTERN" 2> /dev/null | grep -q "."
                if [ $? == 0 ]; then

                        ARRAY_MODIFY_DATE=($(find $DIR_LOG -maxdepth 1 -type f -name "$PATTERN" -exec $GET_DATE_LAST_MODIFIED {} \; | cut -d " " -f 1 | sort | uniq))

                        for d in ${!ARRAY_MODIFY_DATE[@]}; do
                        if [ ! -d $DIR_LOG_BACKUP ]; then
                                mkdir $DIR_LOG_BACKUP
                        fi
                        if [ ! -d $DIR_LOG/${ARRAY_MODIFY_DATE[$d]} ]; then
                                mkdir $DIR_LOG/${ARRAY_MODIFY_DATE[$d]}
                        fi
                        if [ ! -d $DIR_LOG_BACKUP/${ARRAY_MODIFY_DATE[$d]} ]; then
                                mkdir $DIR_LOG_BACKUP/${ARRAY_MODIFY_DATE[$d]}
                        fi
                        done

                        for f in $DIR_LOG/$PATTERN; do
                                FILE_MODIFY_DATE=$($GET_DATE_LAST_MODIFIED $f | cut -d " " -f 1)
                                if [[ "${ARRAY_MODIFY_DATE[*]}" =~ (^|[[:space:]])"$FILE_MODIFY_DATE"($|[[:space:]]) ]]; then
                                        mv --backup=existing $f $DIR_LOG/$FILE_MODIFY_DATE
                                fi
                        done

                        for d in ${!ARRAY_MODIFY_DATE[@]}; do
                                $COMPRESSION $DIR_LOG/${ARRAY_MODIFY_DATE[$d]}/$PATTERN 2> /dev/null
                                cp -u $DIR_LOG/${ARRAY_MODIFY_DATE[$d]}/* $DIR_LOG_BACKUP/${ARRAY_MODIFY_DATE[$d]}
                                SIZE_LOCAL=$(du -cb $DIR_LOG/${ARRAY_MODIFY_DATE[$d]}/* | tail -1 | awk -F " " '{print $1}')
                                SIZE_BACKUP=$(du -cb $DIR_LOG_BACKUP/${ARRAY_MODIFY_DATE[$d]}/* | tail -1 | awk -F " " '{print $1}')
                                if [ $SIZE_LOCAL != $SIZE_BACKUP ]; then
                                        echo "$(date +"%F %T") $DIR_LOG/${ARRAY_MODIFY_DATE[$d]} is not equal after backup" >> /tmp/log_rotate_err.log
                                fi
                        done

                fi
done
