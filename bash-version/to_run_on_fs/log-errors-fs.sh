#!/bin/bash

#######################################################################################################################################
#
# This script watches a live log file for ERROR matches. If found, it appends the error code and messages to a file.
# It is designed assuming that an alarm system will be triggered if the STATUS_FILE is non-empty. That is, no alarm if status file does not exist or is empty.
# Runs on FS pushes status file to the  Ny Mitra Alarm System.
# This version relies on FS function to get the present/current log file.
# 
#######################################################################################################################################

# FUNCTIONS:

get_config() {
	###
	if $DEBUG; then echo "get_config()"; fi
	###
	# Read in (source) variables from configuration file:
	. ./log-errors.cfg
	###
	if $DEBUG; then
		echo "Status file: $STATUS_FILE"
		echo "Time till timeout: $TIMEOUT_TIME seconds"
		echo "User of host: $NM_USER"
		echo "Address of host: $NM_HOST"
		echo "Directory of alarm system: $ALARM_SYSTEM_DIRECTORY"
	fi
}

finisher() {
	###
	if $DEBUG; then echo "finisher()"; fi
	###
	# Properly kill the tail processes
	kill "$PID" &>/dev/null							#otherwise tail will keep running...
}

# Catch signals and close correctly
trap "finisher; exit 0" SIGINT
trap "exit 0" SIGTERM

sync_status_to_alarm_system() {
	###
	if $DEBUG; then echo "sync_status_to_alarm_system()"; fi
	# RSYNC STATUS FILE TO NY MITRA
	#rsync "${STATUS_FILE}" "${NM_USER}@${NM_HOST}:${ALARM_SYSTEM_DIRECTORY}"
}

main() {
	###
	if $DEBUG; then echo "main()"; fi
	###

	PID=$$
	if $DEBUG; then echo "PID $PID"; fi

	###
	get_config

	# Log file with path:
	#LOG_FILE="/usr2/log/${1}.log"
	LOG_FILE="${1}.log"

	###
	if $DEBUG; then echo "Expect log file: ${LOG_FILE}"; fi
	###

	if [ -f "$LOG_FILE" ]; then		#check existence of log file
		if $DEBUG; then echo "Found log!"; fi
		# Empty (or create) the status file
		echo -n > "$STATUS_FILE"

		timeout "${TIMEOUT_TIME}" tail -f "${LOG_FILE}" --pid="$PID" | \
		while read -r line; do
			if echo "$line" | grep -q "ERROR"; then				# if a line in the tail has the word error
				if ! grep -Fxq "$line" log-errors.cfg; then		# & if the line is NOT in the .cfg file (note this might be too strict...)
					echo "$line" >> "$STATUS_FILE"				# then print to status file.
					sync_status_to_alarm_system					# RSYNC STATUS FILE TO NY MITRA
					###
					if $DEBUG; then echo "ERROR!"; fi
					###
				fi
			fi
		done
		# Catch program errors...
		exit_code=${PIPESTATUS[0]}  #$?							# to catch errors thrown by timeout.
		if [ "$exit_code" -eq 124 ]; then						# so we know if it timed-out
			if $DEBUG; then echo "Timeout!"; fi
			echo "Warning. Log file timed out." >> "$STATUS_FILE"
		elif [ "$exit_code" -ne 0 ]; then						# other non-timeout related exit codes
			if $DEBUG; then echo "Error occurred while excuting tail or SSH."; echo; fi
		fi
		###
		echo "Exiting Log Error Monitor." >> "$STATUS_FILE"		# we're outta here
		sync_status_to_alarm_system								# RSYNC STATUS FILE TO NY MITRA
		finisher
		###

	else
		if $DEBUG; then echo "Log file $LOG_FILE not found!"; fi
		exit 2													# couldn't find the log file
	fi

}

#######################################################################################################################################
###
DEBUG=false

# Check positional parameters:
# -d switch to turn on debug.
if [ "$#" -eq 1 ] && [ "$1" == "-d" ]; then		# Recall: $# = len(#@)
	echo "Debug Mode: ON"
	DEBUG=true
fi
###
main $(./lognm)
# lognm is a c script on FS that prints to standard output the current log name.... (generally includes the telescope code)

#######################################################################################################################################
