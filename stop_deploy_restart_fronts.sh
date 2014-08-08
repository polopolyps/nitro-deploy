#!/bin/bash

SCRIPTPATH="$(cd "${0%/*}" 2>/dev/null; echo "$PWD"/"${0##*/}")"
BASEPATH=`dirname $SCRIPTPATH`
CONFIG_FILE="$BASEPATH/config.sh"
source $CONFIG_FILE

#
# STOP, DEPLOY AND START FRONT SERVERS
#

# Demands confirmation from user to continue
function setFrontinVarnish {
    for VARNISH_SERVER in ${VARNISH_SERVERS[@]}
    do
        echo "Setting $1 to $2 on $VARNISH_SERVER"
        ssh $POLOPOLY_USER@$VARNISH_SERVER sudo "\`which varnishadm\`" -T $VARNISH_ADM_URL -S $VARNISH_ADM_SECRET backend.set_health $1 $2
        [ $? -eq 0 ] || die "Failed to set front to sick"
    done

}

unzip -oq $RELEASEDIRECTORY/deployment-config/config.zip -d $RELEASEDIRECTORY/deployment-config/config

# Loop over fronts first

for FRONT_IDX in ${!FRONT_SERVERS[@]}
do
  FRONT=${FRONT_SERVERS[$FRONT_IDX]}
  VARNISH_NAME=${FRONT_VARNISH_NAMES[$FRONT_IDX]}

  echo "Processing front server $FRONT - Setting it to sick"

  setFrontinVarnish $VARNISH_NAME "sick"

  ssh $POLOPOLY_USER@$FRONT "sudo /etc/init.d/$TOMCAT_NAME stop $POLOPOLY_USER"

  [ $? -eq 0 ] || die "Failed to stop tomcat on remote server ($FRONT)"

done


for FRONT_IDX in ${!FRONT_SERVERS[@]}
do
    FRONT=${FRONT_SERVERS[$FRONT_IDX]}
    echo "Checking $FRONT is stopped"
    stopTomcat "$FRONT"
done

for FRONT_IDX in ${!FRONT_SERVERS[@]}
do
  FRONT=${FRONT_SERVERS[$FRONT_IDX]}
  VARNISH_NAME=${FRONT_VARNISH_NAMES[$FRONT_IDX]}

  echo "Processing front server $FRONT - Deploying"

  ssh $POLOPOLY_USER@$FRONT "rm -rf $TOMCAT_HOME/webapps/*"
  [ $? -eq 0 ] || die "Failed to cleanup webapps folder"

  scp -B $RELEASEDIRECTORY/deployment-front/* $POLOPOLY_USER@$FRONT:$TOMCAT_HOME/webapps/.

  [ $? -eq 0 ] || die "Failed to transfer WAR files"

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

  ssh $POLOPOLY_USER@$FRONT sudo /etc/init.d/$TOMCAT_NAME start $POLOPOLY_USER

  [ $? -eq 0 ] || die "Failed to restart tomcat"

  sleep 15

  for URL in ${FRONT_WARMING_URLS[@]}
  do
    STATUS=$(curl -s -L -o /dev/null -w '%{http_code}' http://$FRONT:$FRONT_TOMCAT_PORT/$URL)
    echo "Request to $URL return $STATUS"
    [ $STATUS -eq 200 ] || inform  "Invalid Result from HTTP request - $STATUS"
  done

  setFrontinVarnish $VARNISH_NAME "healthy"
done
