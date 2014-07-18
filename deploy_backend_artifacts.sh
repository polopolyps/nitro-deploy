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
  FOLDER_NAME="${FILENAME%.*}"
  echo "Removing old folder $TOMCAT_HOME/webapps/$FOLDER_NAME"
  ssh $POLOPOLY_USER@$HOST rm -rf $TOMCAT_HOME/webapps/$FOLDER_NAME

  echo "Deploying $FILENAME to $HOST"
  scp -B $RELEASEDIRECTORY/$FILENAME $POLOPOLY_USER@$HOST:$TOMCAT_HOME/webapps/.
  [ $? -eq 0 ] || die "Failed to deploy $FILENAME"


done
 
