#!/bin/bash
####################################################################
# This is the main release script
#
# There should be no evironment specific configuration in this file
# All configuration goes into deploy/${targetEnv}.config
####################################################################

DEPLOYENVIRONMENT="$0"
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

checkMandatoryVariables
if [ "$?" != "0" ]
then
  echo -e "$ERROR Missing mandatory variable in config file \"$CONFIG_FILE\". Stopping!"
  exit 1
fi


step1(){
inform "Step 1. Stopping backend tomcat servers"
./stop_backend_tomcats.sh
if [ "$?" != "0" ]
then
  echo -e "$ERROR Failed stop_remote_tomcats. Stopping!"
  exit 1
fi
}

step2(){
if [ $JBOSS_REDEPLOY ] ; then
 inform "Step 2. Redeploying Jboss artifacts"
 #
 ./deploy_jboss_ear.sh
 if [ "$?" != "0" ]
 then
 echo -e "$ERROR Failed jboss stop. Stopping!"
 exit 1
 fi
else
 inform "Skipping (JBOSS_REDEPLOY or CLEAN_DB not set): Step 2. Stopping jboss."
fi
}

step3(){
#
# DISTRIBUTE THE RELEASE ON THE BACKEND
#
inform "Step 3. Distributing backend webapps."
./deploy_backend_artifacts.sh
if [ "$?" != "0" ]
then
  echo -e "$ERROR Failed deploy_admin. Stopping!"
  exit 1
fi
}

step4(){
inform "Step 4. Distributing SOLR config files"
./deploy_solr_config.sh
if [ "$?" != "0" ]
then
  echo -e "$ERROR Failed deploy_solr. Stopping!"
  exit 1
fi
}


step5(){
inform "Step 5. Importing project content."
./import_content.sh
if [ "$?" != "0" ]
then
  echo -e "$ERROR Failed import_content. Stopping!"
  exit 1
fi
}

step6(){
inform "Step 6. Starting backend tomcat servers."
./start_backend_tomcats.sh
if [ "$?" != "0" ]
then
  echo -e "$ERROR Failed start_remote_tomcats. Stopping!"
  exit 1
fi
}

step7(){
inform "Step 7. Stopping tomcat, distributing webapps and restarting tomcat on fronts."
./stop_deploy_restart_fronts.sh
if [ "$?" != "0" ]
then
  echo -e "$ERROR Failed stop_deploy_restart_fronts. Stopping!"
  exit 1
fi
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
*) echo "Invalid step number $1" ;;
esac
}
NUM_STEPS=7

if [ -n "$2" ]; then
 if ! [[ $1 =~ ^[0-9]+$ ]] || ! [[ $1 -ge 0 ]] || ! [[ $1 -le $NUM_STEPS ]]; then
   echo "$1 is not a valid step number! (1-$NUM_STEPS)"
   exit 1
 fi
fi

START="$1"; shift
[ -z "$START" ] && START=1
for i in $(seq "$START" $NUM_STEPS); do
 runstep $i
done
inform "The release is finished!"
