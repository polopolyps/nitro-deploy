#!/bin/bash
################################################################
# This script will source the correct configuration file 
# for the current environment.
# Environment information is extracted from the hostname
################################################################

MUSTBEDEFINED=(RELEASEDIRECTORY DEPLOYENVIRONMENT FRONT_SERVERS BACKEND_SERVERS SERVER_ARTIFACTS)

DEPLOY_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

if [ -z "$DEPLOYENVIRONMENT" ]
  then
    echo "DEPLOYENVIRONMENT has not been defined"
    exit 1
fi

source $DEPLOY_DIR/common.config
source $DEPLOY_DIR/$DEPLOYENVIRONMENT.config

CONFIG_LOADED=true

CONNECTION_URL="http://$JBOSS_HOST:8081/connection-properties/connection.properties"

###############################################
# Non installation specific variables follows 

COL_RED="\x1b[31;01m"
COL_ORANGE="\x1b[33;01m"
COL_BLUE="\x1b[34;01m"
COL_PURPLE="\x1b[35;06m"
COL_RESET="\x1b[39;49;00m"

# Pre-defined, colorized text strings
ERROR=$COL_RED"ERROR"$COL_RESET
WARNING=$COL_ORANGE"WARNING"$COL_RESET

##############################################
# General functions

die () {
    echo -e $ERROR - $@
    exit 1
}

# Demands confirmation from user to continue
function getConfirmation {
	while true; do
		read -p "Do you want to continue? (y/n):" yn
			case $yn in
			[Yy]* ) break;;
			[Nn]* ) return 1;;
			* ) echo "Please answer yes or no.";;
			esac
	done
	return 0
}

# Demands confirmation from user to continue
function getAnswer {
	while true; do
		read -p "$1 : " ans
		if [[ $ans = $2 ]] ; then return 0; fi;
		echo "Please answer $2"
   done
   return 1
}

function waitForJboss {
    SLEEP_TIME=5
    MAX_TRIES=60
    echo -n "Waiting for for Jboss to start: "
    while [ 1 = 1 ]; do
      [ $MAX_TRIES -eq 0 ] && echo " max wait exceeded. halting deploy!" && exit 1
      let MAX_TRIES-=1
      echo -n "."
      curl $CONNECTION_URL &>/dev/null
      [ $? -eq 0 ] && echo " Jboss is up!"  && return 0
      sleep $SLEEP_TIME
    done
}

# Sleep for a number of seconds, given by the argument
# If no argument is given, it defaults to 5 seconds 
function sleepFor {
	SLEEP_TIME=5
		if [ ! -z "$1" ] 
			then
				SLEEP_TIME=$1
				fi

				echo -n "Waiting for $SLEEP_TIME seconds: " 
				for SECOND in `seq $SLEEP_TIME -1 1` 
					do
						echo -n "$SECOND, "
							sleep 1
							done
							echo "0"
}

# Echoes the message given as argument 1 to screen
# A color code for the text can be given as argument 2 
# if no color code is supplied, default is purple
function inform {
	TEXTCOLOR=$COL_PURPLE
		if [ ! -z $2 ]
			then
				TEXTCOLOR=$2
				fi 
				echo -e $TEXTCOLOR"$1"$COL_RESET
}

# Check for mandatory variables that are critical, in order to minimize 
# the risk of a release script malfunctions
function checkMandatoryVariables {
	if [ -z "$MUSTBEDEFINED" ]
		then
			echo "Could not find info about mandatory variables in config file"
			return 1 
			fi
			for MANDATORY in ${MUSTBEDEFINED[@]}
	do
		VARIABLE=${!MANDATORY}
	if [ -z "$VARIABLE" ]
		then 
			echo "Undefined variable \"$MANDATORY\""
			return 1
			fi
			done
			return 0
}

function waitForTomcat {
    getTomcatInstance "$2"

    echo "Checking $TOMCAT_INSTANCE tomcat instance on $1 / $TOMCAT_HOME"


    CMD="ssh $POLOPOLY_USER@$1 ps x -e | grep '$TOMCAT_HOME' | grep -v grep | cut -d ' ' -f 1"
    TOMCAT_PID=`$CMD`
    if [ "$TOMCAT_PID" ]; then
        echo "Tomcat is still running on $FRONT, pid = $TOMCAT_PID"
        sleepFor 10
        TOMCAT_PID=`$CMD`
        if [ "$TOMCAT_PID" ]; then
            ssh $POLOPOLY_USER@$1 sudo kill -9 $TOMCAT_PID
        fi
    fi

}

function stopTomcat {
  getTomcatInstance "$2"


  echo "Stopping $TOMCAT_INSTANCE tomcat instance on $1 / $TOMCAT_HOME"

  ssh $POLOPOLY_USER@$1 "$TOMCAT_STOP_COMMAND"

  [ $? -eq 0 ] || die "Failed to stop tomcat $TOMCAT_INSTANCE on remote server ($1)"
}

function getTomcatInstance {
  TOMCAT_INSTANCE=$1
  i="TOMCAT_INSTANCES_${TOMCAT_INSTANCE}_home"
  TOMCAT_HOME="${!i}"

  i="TOMCAT_INSTANCES_${TOMCAT_INSTANCE}_shutdown"
  TOMCAT_STOP_COMMAND="${!i}"

  i="TOMCAT_INSTANCES_${TOMCAT_INSTANCE}_startup"
  TOMCAT_START_COMMAND="${!i}"
}


function startTomcat {
  getTomcatInstance "$2"

  echo "Stopping $TOMCAT_INSTANCE tomcat instance on $1 / $TOMCAT_HOME"

  ssh $POLOPOLY_USER@$1 "$TOMCAT_START_COMMAND"

  [ $? -eq 0 ] || die "Failed to start tomcat $TOMCAT_INSTANCE on remote server ($1)"
}