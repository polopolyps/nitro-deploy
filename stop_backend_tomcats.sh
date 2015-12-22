#!/bin/bash
# Stop remote tomcats on admin and search

SCRIPTPATH="$(cd "${0%/*}" 2>/dev/null; echo "$PWD"/"${0##*/}")"
BASEPATH=`dirname $SCRIPTPATH`
CONFIG_FILE="$BASEPATH/config.sh"
source $CONFIG_FILE

for SERVER in ${BACKEND_SERVERS[@]}
do
    IFS=';' read -ra DATA <<< "$SERVER"
    HOST=${DATA[0]}
    TOMCAT_INSTANCE=${DATA[1]}

    stopTomcat "$HOST" "$TOMCAT_INSTANCE"
    waitForTomcat "$HOST" "$TOMCAT_INSTANCE"
done
