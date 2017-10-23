#!/usr/bin/ksh

###########################
##
##	File: rman_daily_incr_backup.sh
##
##	Author: Jesus Sanchez (jsanchez.consultatnt@gmail.com)
##
##	Copyright Notice: Creative Commons Attribution-ShareAlike 4.0 International License
##
##	Sample run: rman_daily_incr_backup.sh -v -d <DATABASE> -l <BACKUP LEVEL>
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
source $SOURCEDIR/oracle_utilities.sh
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
	msgPrint -none "Usage: rman_daily_incr_backup.sh [-v] [--test] [-d <DBNAME>|-f <DB LIST FILE>] -u <USER LIST>"
	msgPrint -none "OPTIONS:"
	msgPrint -none "	-v|--verbose : Verbose mode. Activates debugging messages."
	msgPrint -none "	-d|--database : Database. Need to provide the database name after this option."
	msgPrint -none "	--dba : DBA username to connect to the database"
	msgPrint -none "	-f|--file : Database List File. Full path to the file that contains 1 adtabase name per line must be provided here."
	msgPrint -none "	-m|--mail : Email address to send the log to."
	msgPrint -none "	-u|--user : Database users to be used or modified by the script."
	msgPrint -none "	-t|--tns : TNS_ADMIN export option"
	msgPrint -none "	--test : Test mode. Avoids any database changing actions to be performed."

}

####################
## MAIN ALGORITHM ##
####################

# Setting up logs
logFile=$TEMPDIR/_rman_daily_incr_backup_$$.log
setupLogs start $logFile
msgPrint -title "Welcome to the rman_daily_incr_backup Script"

# Setting profiling (captures running time)
profiling start "rman_daily_incr_backup_profile_$$"

# Variables
export TEST=0
export DEBUG=0
export SILENT=0
email_to=""
database=""
databaseList=""
instanceName=""
localMode=0

if [ $# -gt 0 ]
then
	# Categorize arguments: Relies on utility_functions.sh
	. getArgs $*
	# Creates GA_OPTIONS and GA_VALUES arrays that hold the values for the arguments.

	# Process arguments and initialize variables
	counter=1
	for option in ${GA_OPTIONS[*]} # Values are in GA_VALUES
	do
		case $option in
			("-h" | "--help")
				printUsage
				;;
			("-v" | "--verbose")
				msgPrint -info "Verbose mode: ON"
				DEBUG=1
				;;
			("-d" | "--database")
				databaseList=${GA_VALUES[$counter]}
				msgPrint -info "Database parameter found: $databaseList"
				;;
			("--dba")
				dbaUser=${GA_VALUES[$counter]}
				msgPrint -info "Using ${dbaUser} to connect to database(s)"
				msgPrint -notice "You'll be prompted for the password soon"
				;;
			("-f" | "--file")
				databaseFile=${GA_VALUES[$counter]}
				msgPrint -info "File parameter found: $databaseFile"
				databaseList=$(cat $databaseFile)
				msgPrint -info "Database parameter found in file:
$databaseList"
				;;
			("-l" | "--level")
				level=${GA_VALUES[$counter]}
				msgPrint "Incremental Backup Level: ${level}"
				;;
			("--local")
				localMode=1
				msgPrint "Local database mode: ON"
				;;
			("-m" | "--mail")
				email_to=${GA_VALUES[$counter]}
				msgPrint -info "Email parameter found: $email_to"
				;;
			("-u" | "--user")
				userList=${GA_VALUES[$counter]}
				msgPrint -info "User parameter found: $userList"
				;;
			("-t" | "--tns")
				TNS_ADMIN=${GA_VALUES[$counter]}
				msgPrint -info "TNS directory parameter found: $TNS_ADMIN"
				;;
			(?)
				msgPrint -warning "Unknown argument"
				printUsage
				exit 1
				;;
		esac
		(( counter+=1 ))
	done
else
	msgPrint -info "No arguments found, using defaults"
fi
# Argument processing done

# Checking for required credentials
if [[ -n ${TNS_ADMIN} || -n ${dbaUser} && ${localMode} -eq 0 ]]
then
	msgPrint -separator
	if [[ -z ${dbaUser} ]]
	then
		msgPrint -input "Please enter the DBA username"
		read dbaUser
		msgPrint -blank
	fi
	if [[ -z ${dbaPswd} ]]
	then
		msgPrint -input "Please enter the DBA password"
		stty -echo
		read dbaPswd
		stty echo
		msgPrint -blank
	fi
	rmanAuth=${dbaUser}/${dbaPswd}@database
elif [[ ${localMode} -eq 1 ]]
then
	rmanAuth="/"
fi


# Cycle through databases
for database in ${databaseList}
do
	setOracleEnvironment ${database}
	rman target /<<EORMAN
#CONFIGURE CHANNEL DEVICE TYPE DISK FORMAT   '/PATH/TO/STORAGE/LOCATION/%d_%T_%U.bck';
#CONFIGURE DEVICE TYPE DISK PARALLELISM 4 BACKUP TYPE TO COMPRESSED BACKUPSET;
#CONFIGURE SNAPSHOT CONTROLFILE NAME TO '/PATH/TO/CONTROLFILE/COPY/STORAGE/snap_${database}.cf';
#CONFIGURE RETENTION POLICY TO RECOVERY WINDOW OF 7 DAYS;
RUN {
	CROSSCHECK BACKUP;
	CROSSCHECK COPY;
	CROSSCHECK ARCHIVELOG ALL;
	DELETE NOPROMPT EXPIRED BACKUP;
	DELETE NOPROMPT EXPIRED COPY;
	DELETE NOPROMPT EXPIRED ARCHIVELOG ALL;
	SQL 'ALTER SYSTEM ARCHIVE LOG CURRENT';
	BACKUP AS COMPRESSED BACKUPSET
	INCREMENTAL LEVEL ${level}
	DATABASE PLUS ARCHIVELOG;
	BACKUP CURRENT CONTROLFILE;
	CROSSCHECK BACKUP;
	CROSSCHECK ARCHIVELOG ALL;
	REPORT OBSOLETE RECOVERY WINDOW OF 6 DAYS;
	DELETE NOPROMPT ARCHIVELOG UNTIL TIME 'sysdate-1' BACKED UP 1 TIMES TO DEVICE TYPE DISK;
	DELETE NOPROMPT OBSOLETE;
	REPORT NEED BACKUP;
}
exit
EORMAN
if [[ $? -ne 0 ]]
then
	FAILURE=1
fi
done

profiling stop "rman_daily_incr_backup_profile_$$"
setupLogs stop $logFile
if [[ -n ${email_to} || FAILURE -eq 1 ]]
then
export timeStamp=$(date +"%Y%m%d")
export hostName=$(hostname)
subject="[SHELL SCRIPT] RMAN Daily incremental Backup"
if [[ -z "${email_to}" ]]
then
	email_to="<DEFAULT EMAIL ADDRESS>"
fi
email_to="${email_to}"
email_from="$(whoami)@${hostName}"
email_msg="<PLEASE ENTER A DESCRIPTIVE MESSAGE HERE>
${logFile}"
cat <<- _EOF_ | /usr/lib/sendmail -t
From: $email_from
To: $email_to
Subject: $subject
Date: $(date +%Y%m%d)
Return-Path: ${email_to}
MIME-Version: 1.0
Content-Type: text/html
$email_msg
_EOF_
fi
