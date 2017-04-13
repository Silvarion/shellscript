#!/usr/bin/ksh

###########################
##
##	File: run_n_times_in_m_mins.sh
##
##	Author: Jesus Sanchez (jsanchez.consultant@gmail.com)
##
##	Copyright Notice: Creative Commons Attribution-ShareAlike 4.0 International License
##
##	Sample run: 
##	Run 3 times every 1 minute --> /path/to/run_n_times_in_m_mins.sh -t 3 -m 1 -c "<YOUR COMMAND>"
##
######################################################################


###############
## FUNCTIONS ##
###############

#####################
# Utility Functions #
#####################

export LAUNCHDIR=$(pwd)
export SOURCEDIR=$( cd -P -- "$(dirname -- "$(command -v -- "$0")")" && pwd -P )
echo $SOURCEDIR
source $SOURCEDIR/utility_functions.sh
if [[ -d $SOURCEDIR/tmp ]]
then
	mkdir -p $SOURCEDIR/tmp
fi
export TEMPDIR=$SOURCEDIR/tmp

##########################
#
#	Function name: printUsage
#
#	Description:
#		This function prints the help about using this script
#
#	Usage: printUsage
#
##############################################
function printUsage {
	msgPrint -title HELP
	msgPrint -blank
	msgPrint -none "Usage: run_n_times_in_m_mins.sh -t <# of times to run> -c <double-quoted command>"
	msgPrint -none "OPTIONS:"
	msgPrint -none "	-c: Double quoted command that has to be run every 1 minute"
	msgPrint -none "	-m: Run every minutes"
	msgPrint -none "	-t: Number of times to run"

}

####################
## MAIN ALGORITHM ##
####################

# Setting up logs
logFile=$TEMPDIR/_run_n_times_in_m_mins_$$.log
setupLogs start $logFile
msgPrint -title "Welcome to the run_n_times_in_m_mins Script"

# Setting profiling (captures running time)
profiling start "run_n_times_in_m_mins_$$"

# Variables

if [ $# -gt 0 ]
then
	# Categorize arguments: Relies on utility_functions.sh
	. getArgs $*
	# Creates GA_OPTIONS and GA_VALUES arrays that hold the values for the arguments.

	# Process arguments and initialize variables
	while [[ $# -gt 0 ]]
	do
		case ${1} in
			("-c")
				shift
				command=${1}
				msgPrint -info "Command ACK: ${command}"
				shift
				;;
			("-m")
				shift
				minutes=${1}
				msgPrint -info "Command will be run every ${minutes} minutes"
				shift
				;;
			("-t")
				shift
				times=${1}
				msgPrint -info "The command will be run ${times} times"
				shift
				;;
			("-h" | "--help")
				printUsage
				;;
			(?)
				msgPrint -warning "Unknown argument"
				printUsage
				exit 1
				;;
		esac
		(( counter+=1 ))
	done
	
	# Check that the same process is not running twice
	currentPID="$$"
	anotherOne=$(ps -ef | grep -v "${currentPID}" | grep run_n_times_in_m_mins | grep -v tee |grep -v grep | tr -s [:space:] | cut -d" " -f2)
	msgPrint -notice "Current PID: ${currentPID} - Another PID: ${anotherOne}" 
	if [[ -n "${anotherOne}" ]]
	then
		msgPrint -critical "This task is already running"
		exit 1
	fi
	
	# Prepare the run
	running=0
	runs=0
	startTimeTag=""
	endTimeTag=""
	## Loop while not running or not enough runs
	while [[ ${running} -eq 0 || ${runs} -lt ${times} ]]
	do
		# If not running
		if [[ ${running} -eq 0 && -z ${startTimeTag} ]]
		then
			startTimeTag=$(date +"%s")
			if [[ -n ${endTimeTag} ]]
			then
				delta=$(( ${endTimeTag}-${startTimeTag} ))
				minTimeTag=$(echo ${delta}/60| bc)
			else
				minTimeTag=2
			fi
			if [[ ${minTimeTag} -ge 1 ]]
			then
				msgPrint -notice "Launching background job"
				${command} &
				commPart=$(echo "${command}" | cut -d" " -f1)
				msgPrint -debug "MAIN:${LINENO}" "Comm Part: ${commPart}"
				childID="$(ps -ef | grep $$ | grep ${commPart} | grep -v run_n_times_in_m_mins | grep -v 'grep' | tr -s " " | cut -d" " -f2)"
				if [[ ${DEBUG} -eq 1 ]]
				then
					ps -ef | grep $$ | grep ${commPart} | grep -v run_n_times_in_m_mins | grep -v 'grep'
					msgPrint -debug "MAIN:${LINENO}" "PS --> ps -ef | grep $$ | grep ${commPart} | grep -v run_n_times_in_m_mins | grep -v 'grep'"
					msgPrint -debug "MAIN:${LINENO}" "Child ID: ${childID}"
				fi
				running=1
				(( runs+=1 ))
				msgPrint -debug "MAIN:${LINENO}" "Runs: ${runs}"
			fi
		# If running
		else
			msgPrint -debug "MAIN:${LINENO}" "Process running!"
			if [[ -n ${childID} ]]
			then
				msgPrint -debug "MAIN:${LINENO}" "ps -ef | grep ${childID}"
				isRunning=$(ps -ef | grep -w ${childID} |grep -v 'ps'|grep -v 'grep' | tr -s [:space:])
				if [[ ${DEBUG} -eq 1 ]]
				then
					msgPrint -debug "MAIN:${LINENO}" "isRunning: ${isRunning}"
					ps -ef | grep ${childID} |grep -v 'ps'|grep -v 'grep' | tr -s [:space:]
				fi
			fi
			if [[ -z ${isRunning} ]]
			then
				endTimeTag=$(date +"%s")
				delta=$(( ${endTimeTag}-${startTimeTag} ))
				minTimeTag=$(echo ${delta}/60| bc)
				if [[ ${minTimeTag} -ge 1 ]]
				then
					startTimeTag=""
					running=0
				fi
			fi
		fi
		endTimeTag=""
		sleep 1
	done
else
	msgPrint -info "No arguments found, nothing to do"
fi
# Argument processing done

profiling stop "run_n_times_in_m_mins_$$"
setupLogs stop $logFile
