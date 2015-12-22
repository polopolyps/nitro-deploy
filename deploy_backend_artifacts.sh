#!/bin/bash
SCRIPTPATH="$(cd "${0%/*}" 2>/dev/null; echo "$PWD"/"${0##*/}")"
BASEPATH=`dirname $SCRIPTPATH`
CONFIG_FILE="$BASEPATH/config.sh"
source $CONFIG_FILE
#
# DEPLOY TO ADMIN SERVERS
#

for SERVER in ${BACKEND_SERVERS[@]}
do
  IFS=';' read -ra DATA <<< "$SERVER"
  HOST=${DATA[0]}

  echo "Cleaning tomcats folder on ($SERVER)"
  getTomcatInstance "polopoly"
  ssh $POLOPOLY_USER@$HOST "rm -rf $TOMCAT_HOME/webapps/*"
  [ $? -eq 0 ] || die "Failed to clean tomcat folder ($SERVER)"

  for CONFIG_FILE in ${TOMCAT_CONFIG_FILES[@]}
  do
      FILE="$RELEASEDIRECTORY/deployment-config/config/tomcat/conf/$CONFIG_FILE"
      if [ -e $FILE ]
      then
        echo "Deploying file $FILE"
        ssh $POLOPOLY_USER@$HOST rm $TOMCAT_HOME/conf/$CONFIG_FILE
        scp -B $FILE $POLOPOLY_USER@$HOST:$TOMCAT_HOME/conf/
      fi
  done
done

for ARTIFACT in ${SERVER_ARTIFACTS[@]}
do
  IFS=';' read -ra DATA <<< "$ARTIFACT"
  FILEPATH=${DATA[0]}
  FILENAME=$(basename "$FILEPATH")
  HOST=${DATA[1]}
  getTomcatInstance "${DATA[2]}"
  FOLDER_NAME="${FILENAME%.*}"
  echo "Removing old folder $TOMCAT_HOME/webapps/$FOLDER_NAME"
  ssh $POLOPOLY_USER@$HOST rm -rf $TOMCAT_HOME/webapps/$FOLDER_NAME
  [ $? -eq 0 ] || die "Failed to remove folder $TOMCAT_HOME/webapps/$FOLDER_NAME"

  echo "Deploying $FILENAME to $HOST"
  scp -B $RELEASEDIRECTORY/$FILEPATH $POLOPOLY_USER@$HOST:$TOMCAT_HOME/webapps/.
  [ $? -eq 0 ] || die "Failed to deploy $FILENAME"


done
 
