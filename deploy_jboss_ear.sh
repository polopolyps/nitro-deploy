#!/bin/sh

SCRIPTPATH="$(cd "${0%/*}" 2>/dev/null; echo "$PWD"/"${0##*/}")"
BASEPATH=`dirname $SCRIPTPATH`
CONFIG_FILE="$BASEPATH/config.sh"
source $CONFIG_FILE


ssh $POLOPOLY_USER@$JBOSS_HOST /etc/init.d/jboss "stop"


# Remove the old instances first, just in case the new ones have a different name/version
ssh $POLOPOLY_USER@$JBOSS_HOST rm $JBOSS_HOME/server/default/deploy/polopoly/cm-server*.ear
ssh $POLOPOLY_USER@$JBOSS_HOST rm $JBOSS_HOME/server/default/deploy/polopoly/connection-properties*.war
ssh $POLOPOLY_USER@$JBOSS_HOST rm $JBOSS_HOME/server/default/deploy/polopoly/content-hub*.war

# Copy the new ones in
scp -Brp $RELEASEDIRECTORY/deployment-cm/* $POLOPOLY_USER@$JBOSS_HOST:$JBOSS_HOME/server/default/deploy/polopoly/.


ssh $POLOPOLY_USER@$JBOSS_HOST /etc/init.d/jboss "start"

if [ "$?" == "0" ]
  then
    echo "Copied cm server ear, connection properties war and content hub war to jboss"
  else
    echo "Failed to copy cm server ear, connection properties war and content hub war"
    exit 1
fi
 
