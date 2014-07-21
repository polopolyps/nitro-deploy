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

[ "$#" -ge 1 ] || die_plain "Usage : $SCRIPT_NAME <target_env> [step_number]"

export DEPLOYENVIRONMENT="$1"
# Very important variables that can cause release script to malfunction if missing
SCRIPTPATH="$(cd "${0%/*}" 2>/dev/null; echo "$PWD"/"${0##*/}")"
BASEPATH=`dirname $SCRIPTPATH`
CONFIG_FILE="$BASEPATH/config.sh"
source $CONFIG_FILE

# Redirect stdin and stdout to log file also
exec > >(tee install.log)
exec 2>&1

STARTINFO="Started "`basename $0`" at "`date`", environment: $DEPLOYENVIRONMENT"
inform "$STARTINFO"

checkMandatoryVariables || die "Missing mandatory variable in config file \"$CONFIG_FILE\""


step1(){
inform "Step 1. Stopping backend tomcat servers"
$BASEPATH/stop_backend_tomcats.sh || die "Failed stop_backend_tomcats"
}

step2(){
if [ $JBOSS_REDEPLOY ] ; then
 inform "Step 2. Redeploying Jboss artifacts"
 #
 $BASEPATH/deploy_jboss_ear.sh || die "Failed jboss stop"

else
 inform "Skipping (JBOSS_REDEPLOY or CLEAN_DB not set): Step 2. Stopping jboss."
fi
}

step3(){
#
# DISTRIBUTE THE RELEASE ON THE BACKEND
#
inform "Step 3. Distributing backend webapps."
$BASEPATH//deploy_backend_artifacts.sh || die "Failed deploy_admin"
}

step4(){
inform "Step 4. Distributing SOLR config files"
$BASEPATH//deploy_solr_config.sh || die "Failed deploy_solr"
}


step5(){
inform "Step 5. Importing project content."
$BASEPATH/import_content.sh || die "Failed import_content"
}

step6(){
inform "Step 6. Starting backend tomcat servers."
$BASEPATH/start_backend_tomcats.sh || die "Failed start_remote_tomcats"
}

step7(){
inform "Step 7. Stopping tomcat, distributing webapps and restarting tomcat on fronts."
$BASEPATH/stop_deploy_restart_fronts.sh || die "Failed stop_deploy_restart_fronts"
}

step8(){
inform "Step 8. Deploying varnish config file"
$BASEPATH/deploy_varnish.sh || die "Failed deploy_varnish.sh"
}


runstep(){
case "$1" in
1) step1 ;;
2) step2 ;;
3) step3 ;;
4) step4 ;;
5) step5 ;;
6) step6 ;;
7) step7 ;;
8) step8 ;;
*) echo "Invalid step number $1" ;;
esac
}
NUM_STEPS=8

if [ -n "$2" ]; then
 if ! [[ $2 =~ ^[0-9]+$ ]] || ! [[ $2 -ge 0 ]] || ! [[ $2 -le $NUM_STEPS ]]; then
   echo "$2 is not a valid step number! (1-$NUM_STEPS)"
   exit 1
 fi
fi

START="$2"; shift
[ -z "$START" ] && START=1
for i in $(seq "$START" $NUM_STEPS); do
 runstep $i
done
inform "The release is finished!"
