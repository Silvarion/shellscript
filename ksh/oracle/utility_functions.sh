#!/usr/bin/ksh

###########################
##
##      File: utility_functions.sh
##
##      Author: Jesus Sanchez (jsanchez.consultant@gmail.com)
##
##	Copyright Notice: Creative Commons Attribution-ShareAlike 4.0 International License
##
##      Usage: Import the script using (if you have it in the same directory as the main script
##              export LAUNCH_DIR=$(pwd)
##              export SOURCE_DIR=$( cd -P -- "$(dirname -- "$(command -v -- "$0")")" && pwd -P )
##              source $SOURCE_DIR/utility_functions.sh
##
######################################################################

        NORM="\033[0m"
        BOLD="\033[1m"
        RED_F="\033[31m"
        RED_B="\033[41m"
        YELLOW_F="\033[33m"
        YELLOW_B="\033[43m"
        GREEN_F="\033[32m"
        GREEN_B="\033[42m"


###############
## FUNCTIONS ##
###############

#####################
# Utility Functions #
#####################

##########################
#
#       Function: continueQuestion
#
#       Description:
#               This function asks the user if all is good to continue
#
#       Usage: continueQuestion
#
##############################################
function continueQuestion {
        STEP=$1
        ANSWER="NONE"
        while [[ $ANSWER != "y" && $ANSWER != "Y" && $ANSWER != "n" && $ANSWER != "N" ]]
        do
                if [[ $ANSWER != "NONE" ]]
                then
                        print "[ATTENTION] Please enter \"y\" or \"n\" without the double quotes and press <ENTER>"
                        print " "
                fi
                print -n "[INPUT] Do you want to continue? (y/n) <ENTER> for [y]: "
                read ANSWER
                if [[ -z $ANSWER ]]
                then
                        ANSWER="y"
                fi
        done
        if [[ $ANSWER = "y" || $ANSWER = "Y" ]]
        then
                return 0
        elif [[ $ANSWER = "n" || $ANSWER = "N" ]]
        then
                exit -1
        fi
}

##########################
#
#       Function name: msgPrint
#
#       Description:
#               This function will print debug messages if the
#       main script was called with the -debug option
#
#       Usage:
#               msgPrint [--nocolor] -<info|warning|debug|error|critical|input> <double-quoted message>
#               msgPrint -<blank|separator>
#
####################
function msgPrint {
	type=""
	case $1 in
			("--nocolor")
				msgColor="FALSE"
				;;
			("-blank")
				type="BLANK"
				;;
			("-critical")
				type="CRITICAL"
				;;
			("-error")
				type="ERROR"
				;;
			("-debug")
				type="DEBUG"
					if [[ -n $2 ]]
					then
							shift
							caller=$1
					else
							caller=$0
					fi
				;;
			("-info")
				type="INFO"
				;;
			("-input")
				type="INPUT"
				;;
			("-notice")
				type="NOTICE"
				;;
			("-none")
				type="NONE"
				;;
			("-percent")
				type="PERCENT"
				;;
			("-plain")
				type="PLAIN"
				;;
			("-separator")
				type="SEPARATOR"
				;;
			("-title")
				type="TITLE"
				;;
			("-warning")
				type="WARNING"
				;;
			(*)
				type="NONE"
				;;
	esac
	shift
	message="$*"

# Print
	if [[ ${type} = "BLANK" ]]
	then
		print " "
	elif [[ ${type} = "DEBUG" ]]
	then
		if [[ $DEBUG -eq 1 ]]
		then
			ts=$(date +"%Y-%m-%d %H:%M:%S")
			print "[$type][$ts][$caller] $message "
		fi
	elif [[ ${type} = "INPUT" ]]
	then
		print -n "[$type] $message: "
	elif [[ ${type} = "SEPARATOR" ]]
	then
		print "----------------------------------------------"
	elif [[ ${type} = "TITLE" ]]
	then
		SPLITTER="================================================="
		print " "
		print "$SPLITTER"
		if [[ ${msgColor} = "FALSE" ]]
		then
			print "${message}"
		else
			print "${BOLD}${message}${NORM}"
		fi
		print " "
		print "$SPLITTER"
		print " "
	elif [[ ${type} = "NONE" ]]
	then
		print "[ $message ]"
	elif [[ ${type} = "PERCENT" ]]
	then
		echo -en "\r\c\b"
		print -n "Percent complete: "
		i=1
		while [[ "${i}" -le 48 ]]
		do
			if [[ "${i}" -le "${message}" ]]
			then
				print -n "="
			else
				print -n " "
			fi
		(( i+=1 ))
		done
		print -n " ${message} % "
		i=52
		while [[ "${i}" -le 100 ]]
		do
			if [[ "${i}" -le "${message}" ]]
			then
				print -n "="
			else
				print -n " "
			fi
			(( i+=1 ))
		done
	elif [[ ${type} = "PLAIN" ]]
	then
		print "$message"
	elif [[ ${type} = "ERROR" ]]
	then
		if [[ ${msgColor} = "FALSE" ]]
		then
			print " -> ${type} <- ${message}"
		else
			print "[${RED_F}$type${NORM}] $message"
		fi
	elif [[ ${type} = "CRITICAL" ]]
	then
		if [[ ${msgColor} = "FALSE" ]]
		then
			print ">>> ${type} <<< ${message}"
		else
			print "[${RED_F}${BOLD}$type${NORM}] ${RED_F}$message${NORM}"
		fi
	elif [[ ${type} = "WARNING" ]]
	then
		if [[ ${msgColor} = "FALSE" ]]
		then
			print "!! ${type} !! ${message}"
		else
			print "[${YELLOW_F}${BOLD}$type${NORM}] $message"
		fi
	else
		print "$message"
	fi
}

##########################
#
#       Function name: getArgs
#
#       Description:
#               This function provides the getopts functionality
#       while allowing the use of long operations and list of parameters.
#       in the case of a list of arguments for only one option, this list
#       will be returned as a single-space-separated list in one single string.
#
#       Pre-reqs:
#               None
#
#       Output:
#               GA_OPTIONS variable will hold the current option
#               GA_VALUES variable will hold the value (or list of values) associated
#                       with the current option
#
#       Usage:
#               You have to source the function in order to be able to access the GA_OPTIONS
#       and GA_VALUES variables
#               . getArgs $*
#
####################
function getArgs {

        # Variables to return the values out of the function
        typeset -a GA_OPTIONS
        typeset -a GA_VALUES

        # Checking for number of arguments
        if [[ -z $1 ]]
        then
                msgPrint -warning "No arguments found"
                msgPrint -info "Please call this function as follows: . getArgs \$*"
                exit 1
        fi

        # Grab the dash
        dash=$(echo $1 | grep "-")
        # Looking for short (-) or long (--) options
        isOption=$(expr index "$dash" "-")
        # Initialize the counter
        counter=0
        # Loop while there are arguments left
        while [[ $# -gt 0 ]]
        do
                if [[ -n $dash && $isOption -eq 1 ]]
                then
                        (( counter+=1 ))
                        GA_OPTIONS[$counter]=$1
                        shift
                else
                        if [[ -z ${GA_VALUES[$counter]} ]]
                        then
                                GA_VALUES[$counter]=$1
                        else
                                GA_VALUES[$counter]="${GA_VALUES[$counter]} $1"
                        fi
                        shift
                fi
                dash=$(echo $1 | grep "-")
                isOption=$(expr index "$dash" "-")
        done
        # Make the variables available to the main algorithm
        export GA_OPTIONS
        export GA_VALUES

        msgPrint -debug "Please check the GA_OPTIONS and GA_VALUES arrays for options and arguments"
        # Exit with success
        return 0
}

##########################
#
#       Function name: setupLogs
#
#       Description:
#               This function will setup alog redirection pipe
#       that will allow to write to console as well as to a logfile.
#
#       Pre-reqs:
#               Use the variable $LOGFILE in the main algorythm with
#       full path and file name.
#
#       Usage:
#               setupLogs <start|stop> <LOGFILE>
#
####################
function setupLogs {
        LOGFILE=$2
        if [[ $1 = "start" ]]
        then
                # set up redirects
                exec 3>&1 4>&2
                FIFO=/tmp/fifo.$$
                [[ -e $FIFO ]] || mkfifo $FIFO
                if [[ -e $LOGFILE ]]
                then
                        tee -a $LOGFILE < $FIFO >&3 &
                else
                        tee $LOGFILE < $FIFO >&3 &
                fi
                PID=$!
                exec > $FIFO 2>&1
                return 0
        elif [[ $1 = "stop" ]]
        then
                PIDLIST=""
                for PROCID in $(ps -ef | grep -v grep | grep "$$" | grep tee | tr -s [:space:] | cut -d" " -f2)
                do
                        if [[ -z $(echo $PROCID | grep tee |tr -d [:space:]) && -z $PIDLIST ]]
                        then
                                PIDLIST="$PROCID"
                        else
                                PIDLIST="$PIDLIST $PROCID"
                        fi
                done
                msgPrint -debug "PIDLIST: $PIDLIST"
                exec 1>&3 2>&4 3>&- 4>&-
                kill -9 $PIDLIST > /dev/null 2>&1
                rm -f /tmp/fifo.$$
                return 0
        fi
        return 0
}
export FIFO

##########################
#
#       Function name: profiling
#
#       Description:
#               This function will setup a log where timestamps will
#       be kept for calculating profiling information
#
#       Pre-reqs:
#               None
#
#       Usage:
#               profiling <start|stop> <SCRIPT|FUNCTION NAME>
#
####################
function profiling {

        caller=${2}
        profileLog=/tmp/${caller}_$$.tmp
        if [[ $1 == "start" || $1 == "START" ]]
        then
                touch $profileLog
                TS=$(date +"%s")
                echo "$2:START:$TS" >> $profileLog
                return 0
        elif [[ $1 == "stop" || $1 == "STOP" ]]
        then
                TS=$(date +"%s")
                echo "$2:STOP:$TS" >> $profileLog
                RT=0
                RTH=0
                RTM=0
                RTS=0
                #cat $profileLog
                STARTTS=$(cat $profileLog | grep START | cut -d":" -f3)
                ENDTS=$(cat $profileLog | grep STOP | cut -d":" -f3)
                RT=$(( ENDTS-STARTTS ))
                if [[ $RT -lt 60 ]]
                then
                        RTS=$RT
                elif [[ $RT -lt 3600 ]]
                then
                        RTM=$( echo $RT / 60 | bc)
                        RT=$( echo $RT % 60 | bc )
                        RTS=$RT
                else
                        RTH=$( echo $RT / 3600 | bc)
                        RT=$(( $RT % 3600 ))
                        RTM=$( echo $RT / 60 | bc)
                        RT=$( echo $RT % 60 | bc )
                        RTS=$RT
                fi
                msgPrint -none "$caller ran during $RTH hours $RTM minutes and $RTS seconds"
                rm -f $profileLog
                return 0
        fi
}

##########################
#
#       Function name: string2array
#
#       Description:
#               This function will fill an array with the provided string
#       splitting values with the given delimiter
#
#       Pre-reqs:
#               Both, the String and the Array must be environment variables (i.e. exported from the caller)
#
#       Usage:
#               string2array -a <ARRAY VARIABLE> -s <STRING VARIABLE> [-d <DOUBLE-QUOTED DELIMITER>]
#
####################
function string2array {
        # Variables BEGIN
        string=""
        typeset -a array
        first=""
        remainder=""
        delim=" "
        # Variables END

        # Process parameters BEGIN
        while [[ $# -gt 0 ]]
        do
                case $1 in
                        ("-a")
                                msgPrint -debug "Got the array variable"
                                shift
                                array=$1
                                shift
                                ;;
                        ("-s")
                                msgPrint -debug "Got the list"
                                shift
                                string=$1
                                shift
                                ;;
                        ("-d")
                                msgPrint -debug "Got the delimiter"
                                shift
                                delim=$1
                                shift
                                ;;
                        (?)
                                msgPrint -debug "Unknown parameter"
                                shift
                                ;;
                esac
        done
        # Process parameters END

        counter=1
        while [[ -n $string ]]
        do
                first=$(echo "$string" | cut -d"$delim" -f1)
                remainder=first=$(echo "$string" | cut -d"$delim" --complement -f1)
                array[$counter]=$first
                string=$remainder
                (( counter+=1 ))
        done

        export array

        return 0

}

##########################
#
#       Function name: dbPassword
#
#       Description:
#               This function wraps up the Perl Functionality from EDM Lending
#			that allows to store/retrieve encrypted passwords from a server file.
#			It’s important to note that this password file keeps “instance” passwords,
#			so it can be used as database or instance password store
#
#       Pre-reqs:
#               This script (utility_functions.sh) must be sourced by using coredbautils.sh which
#			sets the $LENDTOOLS environmental variable to reach the Perl scripts.
#
#       Usage:
#               dbPassword {LS|LIST}
#				dbPassword {DEL|DELETE|GET|UPD|UPDATE|SET} <INSTANCE> <USERNAME>
#
####################
function dbPassword {
	typeset -u action
	typeset -u username
	action=${1}
	instance=${2}
	username=${3}

	case $action in
		("LS"|"LIST")
			# List contents of theserver file
			${LENDTOOLS}/passwd_display.pl -L
			;;
		("DEL"|"DELETE")
			# Delete encrypted password from the server file
			if [[ -z ${instance} || -z ${username} ]]
			then
				msgPrint -critical "Please provide Instance name and Username"
				msgPrint -notice "dbPassword -a delete -i <instance_name> -u <username>"
				return 1
			else
				${LENDTOOLS}/del_passwd.pl -S${instance} -U${username}
			fi
		;;
		("GET")
			# Get encrypted password from the server file
			if [[ -z ${instance} || -z ${username} ]]
			then
				msgPrint -critical "Please provide Instance name and Username"
				msgPrint -notice "dbPassword -a get -i <instance_name> -u <username>"
				return 1
			else
				resultPass=$(${LENDTOOLS}/passwd_display.pl -L | grep -i ${instance} | grep -i ${username} | tr -s " " | cut -d" " -f3)
				if [[ -z ${resultPass} ]]
				then
					msgPrint -critical "No entry found for that instance (${instance}) and user (${username})"
				else
					echo ${resultPass}
				fi
			fi
		;;
		("UPD"|"UPDATE")
			# Set a new password in the server file
			if [[ -z ${instance} || -z ${username} ]]
			then
				msgPrint -critical "Please provide Instance name and Username"
				msgPrint -notice "dbPassword -a set -i <instance_name> -u <username>"
				return 1
			else
				# Ask for password
				msgPrint -input "Please enter the password for user ${username}"
				stty -echo
				read encPasswd
				stty echo
				msgPrint -blank
				${LENDTOOLS}/chg_passwd.pl -S${instance} -U${username} -P${encPasswd}
			fi
		;;
		("SET")
			# Set a new password in the server file
			if [[ -z ${instance} || -z ${username} ]]
			then
				msgPrint -critical "Please provide Instance name and Username"
				msgPrint -notice "dbPassword -a set -i <instance_name> -u <username>"
				return 1
			else
				# Check for existing entries
				resultPass=$(${LENDTOOLS}/passwd_display.pl -L | grep -i ${instance} | grep -i ${username} | tr -s [:space:] | cut -d' ' -f3)
				if [[ -z ${resultPass} ]]
				then
				msgPrint -input "Please enter the password for user ${username}"
				stty -echo
				read encPasswd
				stty echo
				msgPrint -blank
				${LENDTOOLS}/enc_passwd.pl -A${instance},${username},${encPasswd}
				else
					msgPrint -notice "Entry for user ${username} @ ${instance} already exists. Please use the UPDATE action"
				fi
			fi
		;;
		(?)
			msgPrint -warning "Unknown action"
			printUsage
			return 1
		;;
	esac
}
