#!/bin/sh

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
        ssh $POLOPOLY_USER@$VARNISH_SERVER sudo varnishadm -T $VARNISH_ADM_URL -S $VARNISH_ADM_SECRET backend.set_health $1 $2
    done

}

TOMCAT_CONFIG_FILES=(server.xml context.xml logging.properties)

unzip -oq $RELEASEDIRECTORY/deployment-config/config.zip -d $RELEASEDIRECTORY/deployment-config/config

for FRONT_IDX in ${!FRONT_SERVERS[@]}
do
  FRONT=${FRONT_SERVERS[$FRONT_IDX]}
  VARNISH_NAME=${FRONT_VARNISH_NAMES[$FRONT_IDX]}

  echo "Processing front server $FRONT"

  setFrontinVarnish $VARNISH_NAME "sick"

  ssh $POLOPOLY_USER@$FRONT sudo /etc/init.d/$TOMCAT_NAME stop
  ssh $POLOPOLY_USER@$FRONT sudo rm -rf $TOMCAT_HOME/webapps/*
  scp -B $RELEASEDIRECTORY/deployment-front/* $POLOPOLY_USER@$FRONT:$TOMCAT_HOME/webapps/.


  for CONFIG_FILE in ${TOMCAT_CONFIG_FILES[@]}
  do

      FILE="$RELEASEDIRECTORY/deployment-config/config/tomcat/conf/$CONFIG_FILE"

      if [ -e $FILE ]
      then
        echo "Deploying file $FILE"
        scp -B $FILE $POLOPOLY_USER@$FRONT:$TOMCAT_HOME/conf/
      fi
  done

  ssh $POLOPOLY_USER@$FRONT sudo /etc/init.d/$TOMCAT_NAME start

  for URL in ${FRONT_WARMING_URLS[@]}
  do
    echo "Processing $URL"
    curl -s http://$FRONT:$FRONT_TOMCAT_PORT/$URL
  done

  setFrontinVarnish $VARNISH_NAME "healthy"

  if [ "$?" == "0" ]
  then
    echo "Stopped tomcat, deployed new front webapp and restarted tomcat ($FRONT)"
  else
    echo "Failed to stop tomcat, deploy new front webapp and restart tomcat ($FRONT)!"
    exit 1
  fi

done
