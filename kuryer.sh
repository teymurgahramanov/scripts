#!/bin/bash
# Assume that you have two servers: apptestsrv1 and appprodsrv2. Each server contains directories /App/FooApp,/App/BarApp. 
# Developers tested apps apptestsrv1 and tell you that packages are ready to be deployed on production. So, you use this script to deliver packages from test to prod.
# Create alias: alias kuryer="sudo -u deploy FILE_LOCK_OWNER=$(whoami) bash /Workdir/Scripts/kuryer.sh"

exec 2> /dev/null
trap " func_exit 1 " SIGINT SIGTERM SIGHUP

FILE_SCRIPT_CONF="/path/to/kuryer.conf"
FILE_LOCK="/tmp/$(basename $0.lock 2> /dev/null)"
DIR_APP="/path/to/appdir"
DIR_APP_BACKUP="/path/to/backupdir"
DEPLOY_USER="kuryer"
APP_OWNER_USER=mamed
APP_OWNER_GROUP=mamed
TIMEFORMAT=%R
TARGET_ENVIRONMENT="$1" #prod|test
DEPLOY_OPTION="$2" #no-conf|app-conf|all-conf

MESSAGE_SUCCESS="Success"
MESSAGE_FAILED="Failed"
MESSAGE_ERROR_NUMBER="ERROR: Only presented numbers!"
MESSAGE_ERROR_SOMETHING="ERROR: Something went wrong!"
MESSAGE_ERROR_HASH="ERROR: Hashes not equal!"
MESSAGE_ERROR_BACKUP_PREV_FILE="ERROR: Previous file not exist!"

ARRAY_APP=($(ls -l $DIR_APP/ | grep "^d" | grep -v total | awk -F " " '{print $9}'))
ARRAY_APP_TYPE=("WAR" "JAR")
ARRAY_TARGET_ENVIRONMENT=("prod" "test")
ARRAY_DEPLOY_OPTIONS=("no-conf" "app-conf" "all-conf")
ARRAY_TARGET_HOST=($(grep HOST $FILE_SCRIPT_CONF | awk -F "," '{print $2}'))
ARRAY_TARGET_HOST_PORT=($(grep HOST $FILE_SCRIPT_CONF | awk -F "," '{print $3}'))
ARRAY_APP_PARAM_BEFORE=($(grep PARAM $FILE_SCRIPT_CONF | awk -F "," '{print $2}'))
ARRAY_APP_PARAM_AFTER=($(grep PARAM $FILE_SCRIPT_CONF | awk -F "," '{print $3}'))

func_exit () {
    echo " "
    func_print error "Exit"
    echo " "
    rm -f $FILE_LOCK
    exit $1
}

func_print () {
    FONT_STEP_COLOR="\e[36m"
    FONT_PROMPT_COLOR="\e[93m"
    FONT_SUCCESS_COLOR="\e[92m"
    FONT_ERROR_COLOR="\e[91m"
    FONT_RESET="\e[0m"

    if [ $1 == "step" ]; then
        echo " "
        echo -e $FONT_STEP_COLOR"$2"$FONT_RESET
    elif [ $1 == "prompt" ]; then
        echo -e $FONT_PROMPT_COLOR"$2"$FONT_RESET
    elif [ $1 == "success" ]; then
        echo -e $FONT_SUCCESS_COLOR"$2"$FONT_RESET
    elif [ $1 == "error" ]; then
        echo -e $FONT_ERROR_COLOR"$2"$FONT_RESET
    fi
}

func_approve () {
    func_print step "Is it OK?"
    while true; do
        read -rp "$(func_print prompt "Answer Y to continue or N to exit: ")" APPROVE 2>&1
        if [[ "$APPROVE" == "Y" ]]; then
            unset APPROVE
            break
        elif [[ $APPROVE == N ]]; then
            func_exit 1
        elif [[ "$APPROVE" != "Y" && "$APPROVE" != "N" ]]; then
            func_print error "ERROR: Only Y or N"
        fi
    done
}

func_result () {
    if [[ $? == 0 ]];
    then
        func_print success "$MESSAGE_SUCCESS"
    else
        func_print error "$MESSAGE_FAILED"
    fi
}

func_menu () {
    ARRAY_INIT=$2[@]
    ARRAY_NAME=($(echo ${!ARRAY_INIT}))
    INPUT=$3
    func_print step "$1"
    for i in ${!ARRAY_NAME[@]}; do
        echo -e "  $i ${ARRAY_NAME[$i]}"
    done
    while true; do
        read -rp "$(func_print prompt "Number: ")" ${INPUT} 2>&1
        if [[ " ${!ARRAY_NAME[@]} " =~ " ${!INPUT} " ]]; then
            break
        elif [[ ! " ${!ARRAY_NAME[@]} " =~ ${!INPUT} ]]; then
            func_print error "$MESSAGE_ERROR_NUMBER"
        elif [[ -z ${!INPUT} ]]; then
            func_print error "$MESSAGE_ERROR_NUMBER"
        fi
    done
}

if [ -f $FILE_LOCK ]; then
    FILE_LOCK_OWNER=$(cat $FILE_LOCK)
    func_print error "ERROR: $0 is busy by $FILE_LOCK_OWNER! Lock file is $FILE_LOCK"
    exit 1
elif [ ! -f $FILE_LOCK ]; then
    echo "$FILE_LOCK_OWNER" > $FILE_LOCK
    chmod 640 $FILE_LOCK
fi

if [[ $1 == "help" || ! " ${ARRAY_TARGET_ENVIRONMENT[@]} " =~ " ${TARGET_ENVIRONMENT} " || ! " ${ARRAY_DEPLOY_OPTIONS[@]} " =~ " ${DEPLOY_OPTION} " || -z "$TARGET_ENVIRONMENT" || -z "$DEPLOY_OPTION" ]]; then
    func_print error 'Usage: kuryer prod|test no-conf|app-conf|all-conf'
    func_exit 1
elif [[ ${#ARRAY_APP_PARAM_BEFORE[@]} != ${#ARRAY_APP_PARAM_AFTER[@]} ]]; then
    func_print error "ERROR: Number of BEFORE and AFTER parameters are NOT equal"
    func_exit 1
fi

if [[ "$DEPLOY_OPTION" != "${ARRAY_DEPLOY_OPTIONS[0]}" ]]; then
    echo " "
    func_print error "$FILE_LOCK_OWNER you choosed config sync option, It can ruin everything!"
    func_approve
fi

while true; do
    func_menu 'Choose application' ARRAY_APP APP_NUMBER
    func_menu 'Choose type' ARRAY_APP_TYPE TYPE_NUMBER

    APPNAME=${ARRAY_APP[$APP_NUMBER]}
    APPTYPE=${ARRAY_APP_TYPE[$TYPE_NUMBER]}

    DIR_APP_SPEC="$DIR_APP/$APPNAME/${APPTYPE^^}"

    func_print step "Checking existence of type $APPTYPE for $APPNAME"
    if [[ -d "$DIR_APP_SPEC" ]]; then
        func_print success "$MESSAGE_SUCCESS"
        break
    elif [[ ! -d "$DIR_APP_SPEC" ]]; then
        func_print error "$MESSAGE_FAILED"
    else
        func_print error "$MESSAGE_ERROR_SOMETHING"
    fi
done

while true; do
    ARRAY_APP_FILE=($( find $DIR_APP_SPEC -maxdepth 1 -type f -printf "%f\n" 2> /dev/null | egrep -i '\.(war|jar|bak|bac|bkp|updt)$' ))
    func_menu 'Choose file' ARRAY_APP_FILE FILE_NUMBER
    SOURCE_APPFILE="${ARRAY_APP_FILE[$FILE_NUMBER]}"
    DESTINATION_APPFILE="$APPNAME.${APPTYPE,,}"
    break
done

while true; do
    func_menu 'Choose host' ARRAY_TARGET_HOST HOST_NUMBER

    TARGET_HOSTNAME=${ARRAY_TARGET_HOST[$HOST_NUMBER]}
    TARGET_HOSTPORT=${ARRAY_TARGET_HOST_PORT[$HOST_NUMBER]}

    func_print step "Checking existence of $DIR_APP_SPEC on $TARGET_HOSTNAME"
    if ssh -p $TARGET_HOSTPORT $DEPLOY_USER@$TARGET_HOSTNAME "[ -d $DIR_APP_SPEC ]"; then
        func_print success "$MESSAGE_SUCCESS"
        break
    elif ssh -p $TARGET_HOSTPORT $DEPLOY_USER@$TARGET_HOSTNAME "[ ! -d $DIR_APP_SPEC ]"; then
        func_print error "$MESSAGE_FAILED"
    else
        func_print error "$MESSAGE_ERROR_SOMETHING"
    fi
done

func_print step "Attention!"
if [[ "$DEPLOY_OPTION" == "${ARRAY_DEPLOY_OPTIONS[0]}" ]]; then
    echo "$SOURCE_APPFILE will be deployed on $TARGET_HOSTNAME at $DIR_APP_SPEC as $DESTINATION_APPFILE"
elif [[ "$DEPLOY_OPTION" == "${ARRAY_DEPLOY_OPTIONS[1]}" ]]; then
    ARRAY_PATH_CONF=("$DIR_APP/$APPNAME/Conf/")
    echo "$SOURCE_APPFILE will be deployed on $TARGET_HOSTNAME at $DIR_APP_SPEC as $DESTINATION_APPFILE with conf files in $(echo "${ARRAY_PATH_CONF[*]}")"
elif [[ "$DEPLOY_OPTION" == "${ARRAY_DEPLOY_OPTIONS[2]}" ]]; then
    ARRAY_PATH_CONF=("$DIR_APP/$APPNAME/Conf/" $(grep EXTRA_PATH $FILE_SCRIPT_CONF | awk -F "," '{print $2}'))
    echo "$SOURCE_APPFILE will be deployed on $TARGET_HOSTNAME at $DIR_APP_SPEC as $DESTINATION_APPFILE with conf files in $(echo "${ARRAY_PATH_CONF[*]}")"
fi

func_approve

func_backup_file () {
    if ssh -p $TARGET_HOSTPORT $DEPLOY_USER@$TARGET_HOSTNAME "[[ -f $DIR_APP_SPEC/$DESTINATION_APPFILE ]]"; then
        ssh -p $TARGET_HOSTPORT $DEPLOY_USER@$TARGET_HOSTNAME "
        sudo cp $DIR_APP_SPEC/$DESTINATION_APPFILE $DIR_APP_BACKUP/$APPNAME/$DESTINATION_APPFILE.$(date +"%Y%m%d-%H%M");"
        func_result
    elif ssh -p $TARGET_HOSTPORT $DEPLOY_USER@$TARGET_HOSTNAME "[[ ! -f $DIR_APP_SPEC/$DESTINATION_APPFILE ]]"; then
        func_print error "$MESSAGE_ERROR_BACKUP_PREV_FILE"
    else
        func_print error "$MESSAGE_ERROR_SOMETHING"
    fi
}

func_backup () {
    func_print step "Backing up previous version to $DIR_APP_BACKUP/$APPNAME"
    if ssh -p $TARGET_HOSTPORT $DEPLOY_USER@$TARGET_HOSTNAME "[[ -d $DIR_APP_BACKUP/$APPNAME ]]"; then
        func_backup_file
    elif ssh -p $TARGET_HOSTPORT $DEPLOY_USER@$TARGET_HOSTNAME "[[ ! -d $DIR_APP_BACKUP/$APPNAME ]]"; then
        ssh -p $TARGET_HOSTPORT $DEPLOY_USER@$TARGET_HOSTNAME "
        sudo mkdir $DIR_APP_BACKUP/$APPNAME"
        if [ $? == 0 ]; then
            func_backup_file
        else
            func_print error "$MESSAGE_ERROR_SOMETHING"
        fi
    else
        func_print error "$MESSAGE_ERROR_SOMETHING"
    fi
}

func_revert () {
    func_print error "$MESSAGE_ERROR_SOMETHING"
    func_print step "Trying to restore previous version"
    if ssh -p $TARGET_HOSTPORT $DEPLOY_USER@$TARGET_HOSTNAME "[ -f "$DIR_APP_SPEC/$DESTINATION_APPFILE.bak" ]"; then
        ssh -p $TARGET_HOSTPORT $DEPLOY_USER@$TARGET_HOSTNAME "
        sudo mv -f $DIR_APP_SPEC/$DESTINATION_APPFILE.bak $DIR_APP_SPEC/$DESTINATION_APPFILE"
        func_result
        func_exit 1
    elif ssh -p $TARGET_HOSTPORT $DEPLOY_USER@$TARGET_HOSTNAME "[ ! -f "$DIR_APP_SPEC/$DESTINATION_APPFILE.bak" ]"; then
        func_print error "No backup file"
        func_exit 1
    fi
}

func_send_appfile () {
    func_print step "Sending $SOURCE_APPFILE to $TARGET_HOSTNAME"
    if ssh -p $TARGET_HOSTPORT $DEPLOY_USER@$TARGET_HOSTNAME "[ -f "$DIR_APP_SPEC/$DESTINATION_APPFILE" ]"; then
        ssh -p $TARGET_HOSTPORT $DEPLOY_USER@$TARGET_HOSTNAME "
        sudo mv -f $DIR_APP_SPEC/$DESTINATION_APPFILE $DIR_APP_SPEC/$DESTINATION_APPFILE.bak"
    fi
    scp -P $TARGET_HOSTPORT $DIR_APP_SPEC/$SOURCE_APPFILE $DEPLOY_USER@$TARGET_HOSTNAME:$DIR_APP_SPEC/$DESTINATION_APPFILE
    if [ $? == 0 ]; then
        ssh -p $TARGET_HOSTPORT $DEPLOY_USER@$TARGET_HOSTNAME "sudo chown $APP_OWNER_USER:$APP_OWNER_GROUP $DIR_APP_SPEC/$DESTINATION_APPFILE"
        func_print success "$MESSAGE_SUCCESS"
    else
        func_print error "$MESSAGE_ERROR_SOMETHING"
        func_exit 1
    fi
}

func_check_equal () {
    func_print step "Comparing hashes"
    HASH_REMOTE="$(ssh -p $TARGET_HOSTPORT $DEPLOY_USER@$TARGET_HOSTNAME md5sum $DIR_APP_SPEC/$DESTINATION_APPFILE | cut -d " " -f 1)"
    HASH_LOCAL="$(md5sum $DIR_APP_SPEC/$SOURCE_APPFILE | cut -d " " -f 1)"
    if [[ "$HASH_LOCAL" == "$HASH_REMOTE" ]]; then
        func_print success "$MESSAGE_SUCCESS"
    else
        func_revert
    fi
}

func_sync_conf () {
    func_print step "Syncing conf files and backing up previous confs"
    for i in ${!ARRAY_PATH_CONF[@]}; do
    ssh -p $TARGET_HOSTPORT $DEPLOY_USER@$TARGET_HOSTNAME "
    yes | sudo cp -Trpf ${ARRAY_PATH_CONF[$i]} ${ARRAY_PATH_CONF[$i]%/}.bak"
    rsync -r -e "ssh -p $TARGET_HOSTPORT" --exclude='*.jks' --delete ${ARRAY_PATH_CONF[$i]} $DEPLOY_USER@$TARGET_HOSTNAME:${ARRAY_PATH_CONF[$i]};
    done
    if [ $? == 0 ]; then
    ssh -p $TARGET_HOSTPORT $DEPLOY_USER@$TARGET_HOSTNAME /bin/bash <<EOF
    HEREDOC_ARRAY_APP_PARAM_BEFORE=(${ARRAY_APP_PARAM_BEFORE[@]})
    HEREDOC_ARRAY_APP_PARAM_AFTER=(${ARRAY_APP_PARAM_AFTER[@]})
    HEREDOC_ARRAY_PATH_CONF=(${ARRAY_PATH_CONF[@]})
    HEREDOC_APP_OWNER_USER=($APP_OWNER_USER)
    HEREDOC_APP_OWNER_GROUP=($APP_OWNER_GROUP)
    for p in \${!HEREDOC_ARRAY_PATH_CONF[@]}; do
    for i in \${!HEREDOC_ARRAY_APP_PARAM_BEFORE[@]}; do
        sudo find \${HEREDOC_ARRAY_PATH_CONF[\$p]} -type f -exec sed -i "s|\${HEREDOC_ARRAY_APP_PARAM_BEFORE[\$i]}|\${HEREDOC_ARRAY_APP_PARAM_AFTER[\$i]}|g" {} +;
        sudo chown -R \$HEREDOC_APP_OWNER_USER:\$HEREDOC_APP_OWNER_GROUP \${HEREDOC_ARRAY_PATH_CONF[\$p]};
    done;
    done
EOF
    func_result
    else
        func_print error "$MESSAGE_ERROR_SOMETHING"
    fi
}

func_restart () {
    func_print step "Restarting $APPNAME"
    TIME_RESTART=$( { time ssh -p $TARGET_HOSTPORT $DEPLOY_USER@$TARGET_HOSTNAME "sudo systemctl restart $APPNAME" > /dev/null; } 2>&1 )
    if [ $? != 0 ]; then
        func_revert
    fi
    sleep 3
    ssh -p $TARGET_HOSTPORT $DEPLOY_USER@$TARGET_HOSTNAME "systemctl is-active --quiet $APPNAME"
    if [ $? != 0 ]; then
        func_revert
    fi
    func_print success "$MESSAGE_SUCCESS"
    func_print success "Restart time: $TIME_RESTART seconds"
    func_exit 0
}

if [[ "$TARGET_ENVIRONMENT" == "${ARRAY_TARGET_ENVIRONMENT[0]}" ]];
then
    func_backup
fi

func_send_appfile
func_check_equal

if [[ "$DEPLOY_OPTION" == "${ARRAY_DEPLOY_OPTIONS[1]}" || "$DEPLOY_OPTION" == "${ARRAY_DEPLOY_OPTIONS[2]}" ]]; then
    func_sync_conf
fi

func_restart
