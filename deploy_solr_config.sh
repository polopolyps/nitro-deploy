#!/bin/sh
SCRIPTPATH="$(cd "${0%/*}" 2>/dev/null; echo "$PWD"/"${0##*/}")"
BASEPATH=`dirname $SCRIPTPATH`
CONFIG_FILE="$BASEPATH/config.sh"
source $CONFIG_FILE
#
# DEPLOY TO ADMIN SERVERS
#
SOLR_HOME_SRC="$RELEASEDIRECTORY/deployment-config/solr-home"
unzip -oq $RELEASEDIRECTORY/deployment-config/solr-home.zip -d $SOLR_HOME_SRC

for SOLR_CONFIG in ${SOLR_SERVERS[@]}
do
  IFS=';' read -ra DATA <<< "$SOLR_CONFIG"

  HOST=${DATA[0]}
  TYPE=${DATA[1]}
  INDEXES=${DATA[2]}
  scp -Brp $SOLR_HOME_SRC/$INDEXES $POLOPOLY_USER@$HOST:$SOLR_HOME/

  if [ "$?" == "0" ]
  then
    echo "Deployed indexes $INDEXES to $TYPE $HOST"
  else
    echo "Failed to deploy $INDEXES to $TYPE $HOST"
    exit 1
  fi
done