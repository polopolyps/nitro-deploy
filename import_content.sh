#!/bin/sh
SCRIPTPATH="$(cd "${0%/*}" 2>/dev/null; echo "$PWD"/"${0##*/}")"
BASEPATH=`dirname $SCRIPTPATH`
CONFIG_FILE="$BASEPATH/config.sh"
source $CONFIG_FILE

IMPORT_FILE="$RELEASEDIRECTORY/deployment-config/project-imports.jar"
echo "Importing from $IMPORT_FILE using $CONNECTION_URL"
java -jar $RELEASEDIRECTORY/deployment-config/polopoly-cli.jar import -p $SYSADMINPWD -c $CONNECTION_URL $IMPORT_FILE
