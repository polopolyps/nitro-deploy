#!/bin/sh
SCRIPTPATH="$(cd "${0%/*}" 2>/dev/null; echo "$PWD"/"${0##*/}")"
BASEPATH=`dirname $SCRIPTPATH`
CONFIG_FILE="$BASEPATH/config.sh"
source $CONFIG_FILE
#
# DEPLOY TO ADMIN SERVERS
#

for ARTIFACT in ${SERVER_ARTIFACTS[@]}
do
  IFS=';' read -ra DATA <<< "$ARTIFACT"
  FILENAME=${DATA[0]}
  HOST=${DATA[1]}
  scp -B $RELEASEDIRECTORY/$FILENAME $POLOPOLY_USER@$HOST:$TOMCAT_HOME/webapps/.

  if [ "$?" == "0" ]
  then
    echo "Deployed $FILENAME to $HOST"
  else
    echo "Failed to deploy $FILENAME to $HOST"
    exit 1
  fi
done
 
