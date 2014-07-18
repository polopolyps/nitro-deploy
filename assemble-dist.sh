#!/bin/sh
####################################################################
# Use this script to build the distribution files from the source folder
####################################################################

DEPLOYENVIRONMENT="$1"
SCRIPTPATH="$(cd "${0%/*}" 2>/dev/null; echo "$PWD"/"${0##*/}")"
BASEPATH=`dirname $SCRIPTPATH`
CONFIG_FILE="$BASEPATH/config.sh"
source $CONFIG_FILE

mvn clean install p:assemble-dist -DtargetEnv=$DEPLOYENVIRONMENT -DskipDemo -DskipTests
