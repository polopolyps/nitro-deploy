#!/bin/bash
# Stop remote tomcats on admin and search

SCRIPTPATH="$(cd "${0%/*}" 2>/dev/null; echo "$PWD"/"${0##*/}")"
BASEPATH=`dirname $SCRIPTPATH`
CONFIG_FILE="$BASEPATH/config.sh"
source $CONFIG_FILE

for SERVER in ${BACKEND_SERVERS[@]}
do
  stopTomcat "$SERVER"
  waitForTomcat "$SERVER"
done
