#!/bin/sh

SCRIPTPATH="$(cd "${0%/*}" 2>/dev/null; echo "$PWD"/"${0##*/}")"
BASEPATH=`dirname $SCRIPTPATH`
CONFIG_FILE="$BASEPATH/config.sh"
source $CONFIG_FILE


ssh $POLOPOLY_USER@$JBOSS_HOST $JBOSS_STOP_COMMAND
[ $? -eq 0 ] || die "Failed to stop Jboss"

# Remove the old instances first, just in case the new ones have a different name/version
ssh $POLOPOLY_USER@$JBOSS_HOST rm $JBOSS_HOME/server/default/deploy/polopoly/cm-server*.ear
ssh $POLOPOLY_USER@$JBOSS_HOST rm $JBOSS_HOME/server/default/deploy/polopoly/connection-properties*.war
ssh $POLOPOLY_USER@$JBOSS_HOST rm $JBOSS_HOME/server/default/deploy/polopoly/content-hub*.war

# Copy the new ones in
scp -Brp $RELEASEDIRECTORY/deployment-cm/* $POLOPOLY_USER@$JBOSS_HOST:$JBOSS_HOME/server/default/deploy/polopoly/.


ssh $POLOPOLY_USER@$JBOSS_HOST $JBOSS_START_COMMAND

[ $? -eq 0 ] || die "Failed to restart Jboss"
 
