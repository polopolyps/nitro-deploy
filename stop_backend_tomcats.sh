#!/bin/sh
# Stop remote tomcats on admin and search

SCRIPTPATH="$(cd "${0%/*}" 2>/dev/null; echo "$PWD"/"${0##*/}")"
BASEPATH=`dirname $SCRIPTPATH`
CONFIG_FILE="$BASEPATH/config.sh"
source $CONFIG_FILE

for SERVER in ${BACKEND_SERVERS[@]}
do
  ssh $POLOPOLY_USER@$SERVER sudo /etc/init.d/$TOMCAT_NAME stop
  if [ "$?" == "0" ]
  then
    echo "Stopped tomcat on remote server ($SERVER)"
  else
    echo "$ERROR Failed to stop tomcat on remote server ($SERVER)"
    exit 1
  fi
done
