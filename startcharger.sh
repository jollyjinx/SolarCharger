#!/bin/bash

cd $(dirname $0)

readonly SCRIPT_NAME=$(basename $0)

log() {
	echo "$@"
	logger -p user.notice -t $SCRIPT_NAME "$@"
}
     
err() {
	echo "$@" >&2
	logger -p user.error -t $SCRIPT_NAME "$@"
}	
        
        
processes=$(ps axwww |perl -ne 'print $1." " if /^\s*(\d+)\s*.*perl (?:solarcharger)\.perl/;')

if [[ -n "$processes" ]];
then
	log "charger process still running. nothing to do"
	exit
fi

log "charger process not running. restarting"

nohup perl solarcharger.perl </dev/null > >(logger -p user.notice -t solarcharger) 2> >(logger -p user.error -t solarcharger)  &

