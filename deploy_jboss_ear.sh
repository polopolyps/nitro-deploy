#!/bin/bash
SCRIPTPATH="$(cd "${0%/*}" 2>/dev/null; echo "$PWD"/"${0##*/}")"
BASEPATH=`dirname $SCRIPTPATH`
CONFIG_FILE="$BASEPATH/config.sh"
source $CONFIG_FILE


unzip -oq $RELEASEDIRECTORY/deployment-config/config.zip -d $RELEASEDIRECTORY/deployment-config/config

curl $CONNECTION_URL &>/dev/null
if [ $? -eq 0 ]
then
    echo " Jboss is up!"
    ssh $POLOPOLY_USER@$JBOSS_HOST $JBOSS_STOP_COMMAND
    [ $? -eq 0 ] || die "Failed to stop Jboss"
fi

# Remove the old instances first, just in case the new ones have a different name/version
ssh $POLOPOLY_USER@$JBOSS_HOST rm -rf $JBOSS_HOME/server/default/tmp
ssh $POLOPOLY_USER@$JBOSS_HOST rm $JBOSS_HOME/server/default/deploy/polopoly/cm-server*.ear
ssh $POLOPOLY_USER@$JBOSS_HOST rm $JBOSS_HOME/server/default/deploy/polopoly/connection-properties*.war
ssh $POLOPOLY_USER@$JBOSS_HOST rm $JBOSS_HOME/server/default/deploy/polopoly/content-hub*.war

# Copy the new ones in
scp -Brp $RELEASEDIRECTORY/deployment-cm/* $POLOPOLY_USER@$JBOSS_HOST:$JBOSS_HOME/server/default/deploy/polopoly/.
[ $? -eq 0 ] || die "Failed to copy JBOSS artefacts"

ssh $POLOPOLY_USER@$JBOSS_HOST mkdir -p $POLOPOLY_CONFIG
scp -Brp $RELEASEDIRECTORY/deployment-config/config/connection.properties $POLOPOLY_USER@$JBOSS_HOST:$POLOPOLY_CONFIG/connection.properties
scp -Brp $RELEASEDIRECTORY/deployment-config/config/ejb-configuration.properties  $POLOPOLY_USER@$JBOSS_HOST:$POLOPOLY_CONFIG/ejb-configuration.properties

ssh $POLOPOLY_USER@$JBOSS_HOST $JBOSS_START_COMMAND

[ $? -eq 0 ] || die "Failed to restart Jboss"

waitForJboss || die "Jboss did not start correctly"
 
