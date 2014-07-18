#!/bin/sh
# Start remote tomcats on admin and search

SCRIPTPATH="$(cd "${0%/*}" 2>/dev/null; echo "$PWD"/"${0##*/}")"
BASEPATH=`dirname $SCRIPTPATH`
CONFIG_FILE="$BASEPATH/config.sh"
source $CONFIG_FILE

for SERVER in ${BACKEND_SERVERS[@]}
do
  echo "Started tomcat on remote server ($SERVER)"
  ssh $POLOPOLY_USER@$SERVER sudo /etc/init.d/$TOMCAT_NAME start $POLOPOLY_USER
  [ $? -eq 0 ] || die "Failed to stop tomcat on remote server ($SERVER)"

done
