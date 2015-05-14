#!/bin/bash
SCRIPTPATH="$(cd "${0%/*}" 2>/dev/null; echo "$PWD"/"${0##*/}")"
BASEPATH=`dirname $SCRIPTPATH`
CONFIG_FILE="$BASEPATH/config.sh"
source $CONFIG_FILE


warm_site () {
		WARMING_WGET_LOGFILE="/tmp/warming-$1-`date "+%Y%m%d"`.log"
		WARMING_START_URL="${1}"
		if [ -z $WARMING_START_URL ]; then
			echo "No starting url set"
			exit 1
		fi 
		nohup wget --no-cache \
			--ignore-length \
			--delete-after \
			--timeout=20 \
			--restrict-file-names=unix \
			--no-directories \
			--level=2 \
			--tries=1 \
			--span-hosts \
			--domains="${WARMING_START_URL}" \
			--recursive \
			--output-file="${WARMING_WGET_LOGFILE}" \
			--user-agent="${WARMING_USER_AGENT}" \
			--directory-prefix=/tmp/warming/${WARMING_START_URL} \
			--no-parent \
			--verbose \
			-e robots=off \
			--reject-regex "\/logout.*|\/login.*|\/register.*|\*.\@*.|.*wegenermail.*|.*p\.gif.*|.*\.pdf.*" \
			"${WARMING_START_URL}" >/dev/null 2>&1 &
									
		echo $!

}



PID_LIST=""
echo "Using User-Agent: '$WARMING_USER_AGENT'"

for SITE in ${WARMING_SITES[@]}
do
	echo "Processing site $SITE"
	PID=$(warm_site ${SITE})
	PID_LIST="${PID_LIST};${PID}"
done

pids_running () {
for PID in ${PIDS[@]}
do
	kill -0 $PID 2> /dev/null && return 0
done

return 1

}

now_ts=$(date +%s)
later_ts=$((now_ts + $WARMING_TIMEOUT*60))

echo "$(date) - Waiting for processes $PID_LIST to end or until $WARMING_TIMEOUT mins has elapsed"

IFS=';' read -ra PIDS <<< "${PID_LIST}"
while pids_running PIDS &&  [ $(date +%s) -lt $later_ts ]; do
	sleep 2
	echo -n "."
done
echo
echo "$(date) - $WARMING_TIMEOUT mins has elapsed"

for PID in ${PIDS[@]}
do
	kill -0 $PID 2> /dev/null && echo "Killing $PID"; kill $PID 2> /dev/null
done

echo "Done"