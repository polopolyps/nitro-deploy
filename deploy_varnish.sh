#!/bin/bash
# Example file that could be used to detect changes in the Varnish configuration script
# And deploy those changes automatically
# Assumes only a single varnish script and the same script can be deployed to each Varnish server
SCRIPTPATH="$(cd "${0%/*}" 2>/dev/null; echo "$PWD"/"${0##*/}")"
BASEPATH=`dirname $SCRIPTPATH`
CONFIG_FILE="$BASEPATH/config.sh"
source $CONFIG_FILE

NOW=`date +%s`

VARNISH_TARGET="/etc/varnish/default.vcl"
NEWFILE="$RELEASEDIRECTORY/deployment-config/config/varnish/default.vcl"
TMPFILE="/tmp/varnish_tmp.vcl"

unzip -oq $RELEASEDIRECTORY/deployment-config/config.zip -d $RELEASEDIRECTORY/deployment-config/config

for VARNISH_SERVER in ${VARNISH_SERVERS[@]}
do
    if [ -f $NEWFILE ]
    then
        echo "Checking for changes in $VARNISH_TARGET"
        MD5ORIG=`ssh $POLOPOLY_USER@$VARNISH_SERVER md5sum $VARNISH_TARGET | awk '{print $1}'`
        [ $? -eq 0 ] || die "Failed to get md5sum of target"
        MD5NEW="$MD5ORIG"
        MD5NEW=`md5sum $NEWFILE | awk '{print $1}'`
        [ $? -eq 0 ] || die "Failed to get md5sum of source"
        if [ "$MD5ORIG" != "$MD5NEW" ]
        then
            echo "Changes detected in $VARNISH_TARGET - copy from $NEWFILE"
            scp $NEWFILE $POLOPOLY_USER@$VARNISH_SERVER:$TMPFILE
            [ $? -eq 0 ] || die "Failed to copy new file to temp"
            ssh $POLOPOLY_USER@$VARNISH_SERVER sudo cp $TMPFILE $VARNISH_TARGET
            [ $? -eq 0 ] || die "Failed to copy new file to target"
            ssh $POLOPOLY_USER@$VARNISH_SERVER sudo "\`which varnishadm\`" -T $VARNISH_ADM_URL -S $VARNISH_ADM_SECRET vcl.load reload$NOW $VARNISH_TARGET
            [ $? -eq 0 ] || die "Failed to load VCL file"
            ssh $POLOPOLY_USER@$VARNISH_SERVER sudo "\`which varnishadm\`" -T $VARNISH_ADM_URL -S $VARNISH_ADM_SECRET vcl.use reload$NOW
            [ $? -eq 0 ] || die "Failed to use VCL file"
        fi
    fi
done
