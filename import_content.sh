#!/bin/bash
SCRIPTPATH="$(cd "${0%/*}" 2>/dev/null; echo "$PWD"/"${0##*/}")"
BASEPATH=`dirname $SCRIPTPATH`
CONFIG_FILE="$BASEPATH/config.sh"
source $CONFIG_FILE

FORCE_OPTION=""

if [ $POLOPOLY_IMPORTS ]; then
    # Check for changes in the polopoly imports
    IMPORT_FILE="$RELEASEDIRECTORY/deployment-config/polopoly-imports.jar"
    echo "Importing from $IMPORT_FILE using $CONNECTION_URL"
    java -jar $RELEASEDIRECTORY/deployment-config/polopoly-cli.jar import -p $SYSADMINPWD -c $CONNECTION_URL $IMPORT_FILE

    [ $? -eq 0 ] || die "Failed to import polopoly content"
    FORCE_OPTION="-f"
fi

IMPORT_FILE="$RELEASEDIRECTORY/deployment-config/project-imports.jar"
echo "Importing from $IMPORT_FILE using $CONNECTION_URL"
java -jar $RELEASEDIRECTORY/deployment-config/polopoly-cli.jar import $FORCE_OPTION -p $SYSADMINPWD -c $CONNECTION_URL $IMPORT_FILE

