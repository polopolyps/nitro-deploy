#!/bin/bash

SCRIPTPATH="$(cd "${0%/*}" 2>/dev/null; echo "$PWD"/"${0##*/}")"
BASEPATH=`dirname $SCRIPTPATH`
CONFIG_FILE="$BASEPATH/config.sh"
source $CONFIG_FILE

#
# STOP, DEPLOY AND START FRONT SERVERS
#

unzip -oq $RELEASEDIRECTORY/deployment-config/config.zip -d $RELEASEDIRECTORY/deployment-config/config

# Loop over fronts first

for FRONT_IDX in ${!FRONT_SERVERS[@]}
do
    FRONT=${FRONT_SERVERS[$FRONT_IDX]}

    IFS=';' read -ra DATA <<< "$FRONT"
    HOST=${DATA[0]}
    TOMCAT_INSTANCE=${DATA[1]}

    stopTomcat "$HOST" "$TOMCAT_INSTANCE"
done


for FRONT_IDX in ${!FRONT_SERVERS[@]}
do
    FRONT=${FRONT_SERVERS[$FRONT_IDX]}
    IFS=';' read -ra DATA <<< "$FRONT"
    HOST=${DATA[0]}
    TOMCAT_INSTANCE=${DATA[1]}
    waitForTomcat "$HOST" "$TOMCAT_INSTANCE"
done

for FRONT_IDX in ${!FRONT_SERVERS[@]}
do
    FRONT=${FRONT_SERVERS[$FRONT_IDX]}
    IFS=';' read -ra DATA <<< "$FRONT"
    HOST=${DATA[0]}
    getTomcatInstance "${DATA[1]}"
    echo "Processing front server $FRONT - Deploying"


  for ARTIFACT in ${FRONT_ARTIFACTS[@]}
    do
      IFS=';' read -ra DATA <<< "$ARTIFACT"
      FILEPATH=${DATA[0]}
      FILENAME=$(basename "$FILEPATH")
      TARGET_TOMCAT_INSTANCE=${DATA[1]}
      if ["$TARGET_TOMCAT_INSTANCE" == "$TOMCAT_INSTANCE"]
      then

          FOLDER_NAME="${FILENAME%.*}"
          echo "Removing old folder $TOMCAT_HOME/webapps/$FOLDER_NAME"
          ssh $POLOPOLY_USER@$HOST rm -rf $TOMCAT_HOME/webapps/$FOLDER_NAME
          [ $? -eq 0 ] || die "Failed to remove folder $TOMCAT_HOME/webapps/$FOLDER_NAME"

          echo "Deploying $FILENAME to $HOST"
          scp -B $RELEASEDIRECTORY/$FILEPATH $POLOPOLY_USER@$HOST:$TOMCAT_HOME/webapps/.
          [ $? -eq 0 ] || die "Failed to deploy $FILENAME"
      fi
  done

  for CONFIG_FILE in ${TOMCAT_CONFIG_FILES[@]}
  do
      FILE="$RELEASEDIRECTORY/deployment-config/config/tomcat/conf/$CONFIG_FILE"
      if [ -e $FILE ]
      then
        echo "Deploying file $FILE"
        ssh $POLOPOLY_USER@$FRONT rm $TOMCAT_HOME/conf/$CONFIG_FILE
        scp -B $FILE $POLOPOLY_USER@$FRONT:$TOMCAT_HOME/conf/
      fi
  done

  startTomcat "$HOST" "$TOMCAT_INSTANCE"

done

sleep 15


for FRONT_IDX in ${!FRONT_SERVERS[@]}
do
  FRONT=${FRONT_SERVERS[$FRONT_IDX]}
  IFS=';' read -ra DATA <<< "$FRONT"
  HOST=${DATA[0]}
  getTomcatInstance "${DATA[1]}"

  echo "Processing front server $FRONT - Warming"
  if [ "$TOMCAT_INSTANCE" == "polopoly" ]
  then
	  for URL in ${FRONT_WARMING_URLS[@]}
	  do
		STATUS=$(curl -s -L -o /dev/null -w '%{http_code}' http://$HOST:$FRONT_TOMCAT_PORT/$URL)
		echo "Request to $URL return $STATUS"
		[ $STATUS -eq 200 ] || inform  "Invalid Result from HTTP request - $STATUS"
	  done
  fi

done
