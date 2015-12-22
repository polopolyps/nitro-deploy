#!/bin/bash
####################################################################
# This is the main release script
#
# There should be no evironment specific configuration in this file
# All configuration goes into deploy/${targetEnv}.config
####################################################################

SCRIPT_NAME="`basename $0`"

die_plain () {
    echo -e "$@"
    exit 1
}

usage () {
die_plain "Usage : $SCRIPT_NAME <target_env> --step <step_number> [--dbupgrade] [--importsystem]";
}

[ "$#" -ge 1 ] || usage

export DEPLOYENVIRONMENT="$1"

# Very important variables that can cause release script to malfunction if missing
SCRIPTPATH="$(cd "${0%/*}" 2>/dev/null; echo "$PWD"/"${0##*/}")"
BASEPATH=`dirname $SCRIPTPATH`
CONFIG_FILE="$BASEPATH/config.sh"
source $CONFIG_FILE

# Redirect stdin and stdout to log file also
LOG_FILE="/tmp/deploy_${DEPLOYENVIRONMENT}_`date +%s`.log"
inform "Logging to $LOG_FILE"

exec > >(tee $LOG_FILE)
exec 2>&1

STARTINFO="Started "`basename $0`" at "`date`", environment: $DEPLOYENVIRONMENT"
inform "$STARTINFO"

checkMandatoryVariables || die "Missing mandatory variable in config file \"$CONFIG_FILE\""



deploy_jboss(){
if [ $JBOSS_REDEPLOY ] ; then
 #
 $BASEPATH/deploy_jboss_ear.sh || die "Failed jboss stop"

 if [ $UPGRADE_DB ] ; then
    db_upgrade || die "Failed to upgrade database"
 fi
 else
    inform "Skipping JBOSS Deploy (JBOSS_REDEPLOY or CLEAN_DB not set)"
fi
}



cache_disable() {

for FRONT_IDX in ${!FRONT_SERVERS[@]}
do
    FRONT=${FRONT_SERVERS[$FRONT_IDX]}
    IFS=';' read -ra DATA <<< "$FRONT"
    HOST=${DATA[0]}
    TOMCAT_INSTANCE=${DATA[1]}
    VARNISH_NAME=${FRONT_VARNISH_NAMES[$FRONT_IDX]}

    echo "Removing $HOST from Varnish Pool"

    setFrontinVarnish $VARNISH_NAME "sick"

done

}


cache_enable() {

getAnswer "Please type 'yes' and press enter to enable the fronts in Varnish" "yes"

for FRONT_IDX in ${!FRONT_SERVERS[@]}
do
    FRONT=${FRONT_SERVERS[$FRONT_IDX]}
    IFS=';' read -ra DATA <<< "$FRONT"
    HOST=${DATA[0]}
    TOMCAT_INSTANCE=${DATA[1]}

    VARNISH_NAME=${FRONT_VARNISH_NAMES[$FRONT_IDX]}

    echo "Enable $HOST in Varnish Pool"

    setFrontinVarnish $VARNISH_NAME "healthy"

done

}

# Demands confirmation from user to continue
function setFrontinVarnish {
    for VARNISH_SERVER in ${VARNISH_SERVERS[@]}
    do
        echo "Setting $1 to $2 on $VARNISH_SERVER"
        ssh $POLOPOLY_USER@$VARNISH_SERVER sudo "\`which varnishadm\`" -T $VARNISH_ADM_URL -S $VARNISH_ADM_SECRET backend.set_health $1 $2
        [ $? -eq 0 ] || die "Failed to set front $1 to $2"
    done

}

db_upgrade () {

inform "Performing database upgrade to $CONNECTION_URL"
java -jar $RELEASEDIRECTORY/deployment-config/polopoly-cli.jar db-upgrade -c $CONNECTION_URL || die "Failed to upgrade DB"

ssh $POLOPOLY_USER@$JBOSS_HOST $JBOSS_STOP_COMMAND
[ $? -eq 0 ] || die "Failed to stop Jboss"

ssh $POLOPOLY_USER@$JBOSS_HOST $JBOSS_START_COMMAND
[ $? -eq 0 ] || die "Failed to stop Jboss"
}


unset POLOPOLY_IMPORTS
unset UPGRADE_DB

START=1
STEPS=("warm_cache.sh" "cache_disable" "stop_backend_tomcats.sh" "deploy_jboss" "deploy_backend_artifacts.sh"  "deploy_solr_config.sh"  "import_content.sh"  "start_backend_tomcats.sh"  "stop_deploy_restart_fronts.sh" "deploy_varnish.sh" "cache_enable")
STEP_DESCRIPTIONS=(
 "Warm existing Varnish Caches"
 "Put Varnish into Deploy Mode"
 "Stopping backend tomcat servers"
 "Redeploying Jboss artifacts"
 "Distributing backend webapps."
 "Distributing SOLR config files"
 "Importing project content."
 "Starting backend tomcat servers."
 "Stopping tomcat, distributing webapps and restarting tomcat on fronts."
 "Deploying varnish config file"
 "Put Varnish into Normal Mode"
)


NUM_STEPS=${#STEPS[@]}

shift
while [ $# -gt 0 ]
do
     key="$1"
     shift
     case $key in
        --upgradedb)
        export UPGRADE_DB="YES"
        ;;
        --importsystem)
        export POLOPOLY_IMPORTS="YES"
        ;;
        --step)
        START="$1"
        if ! [[ $START =~ ^[0-9]+$ ]] || ! [[ $START -ge 0 ]] || ! [[ $START -le $NUM_STEPS ]]; then
            die "$START is not a valid step number! (0-$NUM_STEPS)"
        fi
        shift;;
        *) usage
     esac
done


if [ $UPGRADE_DB ] ; then
    inform "WARNING - Upgrading database is enabled"
    getConfirmation || die "Release aborted"
    inform "WARNING - Please confirm again that you want to upgrade the database"
    getConfirmation || die "Release aborted"
    export POLOPOLY_IMPORTS="YES"
fi

START_INDEX=$(($START - 1))
END_INDEX=$((NUM_STEPS - 1))

for i in $(seq "$START_INDEX" $END_INDEX); do
 STEP_NUM=$(($i + 1))
 echo "Step $STEP_NUM : ${STEP_DESCRIPTIONS[$i]}"
 STEP="${STEPS[$i]}"
 SCRIPT_FILE="$BASEPATH/$STEP"
 if [ -f $SCRIPT_FILE ]; then
    $SCRIPT_FILE || die "Error executing step $STEP_NUM in $SCRIPT_FILE"
 else
    eval $STEP || die "Error Calling function ${STEPS}"
 fi
done

inform "The release is finished!"
