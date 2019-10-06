#!/usr/bin/ksh

###########################
##
##	File: awr_addm_reports.sh
##
##	Author: Jesus Sanchez (jsanchez.consultant@gmail.com)
##
##	Sample run: awr_addm_reports.sh -v [--db <DB NAME>] [-m <EMAIL ADDRESS>] [-t <TNS_ADMIN_PATH>]
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
source $SOURCEDIR/../utility_functions.sh
source $SOURCEDIR/../oracle_utilities.sh
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
	msgPrint -none "Usage: awr_addm_reports.sh [-v] [--test] [--cod <DBNAME> --hula <DBNAME>"
	msgPrint -none "OPTIONS:"
	msgPrint -none "	-v|--verbose : Verbose mode. Activates debugging email_msgs."
	msgPrint -none "	-m|--mail : Email address to send the log to."
	msgPrint -none "	-t|--tns : TNS_ADMIN export option"
	msgPrint -none "	--test : Test mode. Avoids any database changing actions to be performed."

}

#######################
## Support functions ##
#######################

##########################
#
#       Function: getSnapNumber
#
#       Description:
#               This function looks for the snapshot number closest
#       to the timestamops provided by the user as inputs
#
#       Usage: getSnapNumber <start|end> <TIMESTAMP>
#               TIMESTAMP format: 'DD-MON-YYYY HH24:MI:SS'
#
##############################################
function getSnapNumber {
        if [[ $1 = "start" ]]
        then
                shift
                snapTS="${*}"
                query="select max(snap_id)
                from dba_hist_snapshot
                where begin_interval_time <= TO_TIMESTAMP('${snapTS}','DD-MON-YYYY HH24:MI:SS')
                and end_interval_time > TO_TIMESTAMP('${snapTS}','DD-MON-YYYY HH24:MI:SS');"
                msgPrint -debug "$LINENO" "${query}"
        elif [[ $1 = "end" ]]
        then
                shift
                snapTS="${*}"
                query="select min(snap_id)
                from dba_hist_snapshot
                where end_interval_time >= TO_TIMESTAMP('${snapTS}','DD-MON-YYYY HH24:MI:SS')
                and begin_interval_time < TO_TIMESTAMP('${snapTS}','DD-MON-YYYY HH24:MI:SS');"
                msgPrint -debug "$LINENO" "${query}"
        else
                print "Nothing to look for"
                return -10
        fi
		spoolFile=${TEMPDIR}/snapshot_$$.txt
        sqlplus -s ${loginCreds}@${database}${asSysdba}<<_EOSNAP_
set heading off
set pagesize 0
set tab off
spool ${spoolFile}
${query}
spool off
exit
_EOSNAP_
        result=$(cat ${spoolFile} | grep -v ">" | tr -d [:space:])
        rm -f ${spoolFile}
        tempSnap=${result}
        echo ${tempSnap} >> ${RUNFILE}
}

##########################
#
#       Function: getSnapTime
#
#       Description:
#               This function looks for the snapshot time based on
#       the snapshot number passed as parameter. it will return
#       begin snapshot time for begin snapshot and ending snapshot
#       time for end snapshot.
#
#       Usage: getSnapTime <start|end> <SNAPSHOT NUMBER>
#
##############################################
function getSnapTime {
        if [[ $1 = "start" ]]
        then
                shift
                query="select min(begin_interval_time) from dba_hist_snapshot where snap_id = $1 and begin_interval_time between sysdate - 7 and sysdate;"
        elif [[ $1 = "end" ]]
        then
                shift
                query="select max(end_interval_time) from dba_hist_snapshot where snap_id = $1 and end_interval_time between sysdate - 7 and sysdate;"
        fi
		spoolFile=${TEMPDIR}/snaptime_$$.tmp
        sqlplus -s ${loginCreds}@${database}${asSysdba}<<_EOTIME_
                set heading off
                set pagesize 0
                set tab off
                spool ${spoolFile}
                ${query}
                spool off
                exit
_EOTIME_
        sed -e 's/^ *//' ${spoolFile}
        result=$(cat ${spoolFile} | grep -v ">")
        rm -f ${spoolFile}
        tempSnapTime=${result}
        echo ${tempSnapTime} >> ${RUNFILE}
}

##########################
#
#       Function: getDBName
#
##############################################
function getDBName {
        query="select db_unique_name from v\$database;"
		spoolFile=${TEMPDIR}/dbname_$$.tmp
        sqlplus -s ${loginCreds}@${database}${asSysdba}<<_EODBID_
                set heading off
                set pagesize 0
                set tab off
                spool ${spoolFile}
                ${query}
                spool off
                exit
_EODBID_
        result=$(cat ${spoolFile} | grep -v ">" | tr -d [:space:])
        rm -f ${spoolFile}
        dbname=${result}
        echo ${database} >> ${RUNFILE}
}

##########################
#
#       Function: getDBID
#
##############################################
function getDBID {
        query="select dbid from dba_hist_sga where snap_id = ${startSnap} and rownum=1 and dbid = (select dbid from v\$database);"
		spoolFile=${TEMPDIR}/dbid_$$.tmp
        sqlplus -s ${loginCreds}@${database}${asSysdba}<<_EODBID_
                set heading off
                set pagesize 0
                set tab off
                spool ${spoolFile}
                ${query}
                spool off
                exit
_EODBID_
        result=$(cat ${spoolFile} |grep -v ">" | tr -d [:space:])
        rm -f ${spoolFile}
        dbid=${result}
        echo ${dbid} >> ${RUNFILE}
}

##########################
#
#       Function: getNumberOfInstances
#
##############################################
function getNumberOfInstances {
        query="select max(instance_number) from dba_hist_sga where snap_id = ${startSnap};"
		spoolFile=${TEMPDIR}/instnum_$$.tmp
        sqlplus -s ${loginCreds}@${database}${asSysdba}<<_EODBID_
                set heading off
                set pagesize 0
                set tab off
                spool ${spoolFile}
                ${query}
                spool off
                exit
_EODBID_
        result=$(cat ${spoolFile} | grep -v ">" | tr -d [:space:])
        rm -f ${spoolFile}
        instances=${result}
        echo ${instances} >> ${RUNFILE}
        return 0
}

##########################
#
#       Function: generateAWRGlobalReport
#
#       Description:
#               This function generates the global AWR report using     the parameters
#       passed (NOTE: they must be complete)
#
#       Usage: generateAWRInstanceReport <DBNAME> <DBID> <BEGIN SNAPSHOT> <END SNAPSHOT>
#
##############################################
function generateAWRGlobalReport {
        sqlplus -s ${loginCreds}@${database}${asSysdba}<<_EOGLOBAL_
                define  db_name      = '$1';
                define  dbid         = $2;
                define  num_days     = 3;
                define  begin_snap   = $3;
                define  end_snap     = $4;
                define  report_type  = 'html';
                define  report_name  = 'awr_${1}_${3}_${4}_report.html'
                @@?/rdbms/admin/awrgrpt.sql
                exit
_EOGLOBAL_
}

##########################
#
#       Function: generateAWRInstanceReport
#
#       Description:
#               This function generates one instance AWR report using the parameters
#       passed (NOTE: They must be complete)
#
#       Usage: generateAWRInstanceReport <DBNAME> <DBID> <INSTANCE #> <INSTANCE NAME> <BEGIN SNAPSHOT> <END SNAPSHOT>
#
##############################################
function generateAWRInstanceReport {
        sqlplus -s ${loginCreds}@${database}${asSysdba}<<_EOGLOBAL_
                define  db_name      = '$1';
                define  dbid         = $2;
                define  inst_num     = $3;
                define  inst_name    = '$4';
                define  num_days     = 3;
                define  begin_snap   = $5;
                define  end_snap     = $6;
                define  report_type  = 'html';
                define  report_name  = 'awr_$4_$5_$6_report.html'
                @@?/rdbms/admin/awrrpti.sql
                exit
_EOGLOBAL_
}

##########################
#
#       Function: generateADDMInstanceReport
#
#       Description:
#               This function generates one instance ADDM report using the parameters
#       passed (NOTE: They must be complete)
#
#       Usage: generateADDMInstanceReport <DBNAME> <DBID> <INSTANCE #> <INSTANCE NAME> <BEGIN SNAPSHOT> <END SNAPSHOT>
#
##############################################
function generateADDMInstanceReport {
        sqlplus -s ${loginCreds}@${database}${asSysdba}<<_EOGLOBAL_
                define  db_name      = '$1';
                define  dbid         = $2;
                define  inst_num     = $3;
                define  inst_name    = '$4';
                define  num_days     = 3;
                define  begin_snap   = $5;
                define  end_snap     = $6;
                define  report_name  = 'addm_$4_$5_$6_report.txt'
                @@?/rdbms/admin/addmrpti.sql
                exit
_EOGLOBAL_
}

##########################
#
#       Function: readTimestamps
#
#       Description:
#               This function reads the timestamps for the reports
#
#       Usage: readTimestamps
#
##############################################
function readTimestamps {
	msgPrint -plain "SNAPSHOTS DATE AND TIME"
	msgPrint -separator
	msgPrint -input "Please enter start time (i.e. 21-JAN-2015 23:00:00)"
	read startTime
	msgPrint -input "Please enter end time (i.e. 21-JAN-2015 23:00:00)"
	read endTime
}

####################
## MAIN ALGORITHM ##
####################

# Setting up logs
logFile=${TEMPDIR}/_awr_addm_reports_$$.log
setupLogs start ${logFile}
msgPrint -title "Welcome to the awr_addm_reports Script"

# Setting profiling (captures running time)
profiling start "awr_addm_reports_profile_$$"

# Variables
export TEST=0
export DEBUG=0
export SILENT=0
email_to=""

if [ $# -gt 0 ]
then
	# Categorize arguments: Relies on utility_functions.sh
	. getArgs $*
	# Creates GA_OPTIONS and GA_VALUES arrays that hold the values for the arguments.

	# Process arguments and initialize variables
	counter=1
	for option in ${GA_OPTIONS[*]} # Values are in GA_VALUES
	do
		case ${option} in
			("-h" | "--help")
				printUsage
				;;
			("-v" | "--verbose")
				msgPrint -info "Verbose mode: ON"
				DEBUG=1
				;;
			("--addm")
				ADDM=1
				msgPrint -info "ADDM Report Requested"
				;;
			("--awr")
				AWR=1
				msgPrint -info "AWR Report Requested"
				;;
			("--db")
				database=${GA_VALUES[${counter}]}
				msgPrint -info "Database parameter found: ${database}"
				;;
			("-m" | "--mail")
				email_to=${GA_VALUES[${counter}]}
				msgPrint -info "Email parameter found: $email_to"
				;;
			("-t" | "--tns")
				TNS_ADMIN=${GA_VALUES[${counter}]}
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
msgPrint -blank
msgPrint -separator
## CHECK ORACLE ENVIRONMENT ##
msgPrint -notice "Checking Oracle environment..."
if [[ -z ${ORACLE_HOME} ]]
then
	msgPrint -critical "PLEASE SET THE ORACLE ENVIRONMENT PRIOR TO RUNNING THIS SCRIPT"
	exit 1
fi
msgPrint -notice "Oracle environment comfirmed"
msgPrint -separator
## LOGIN STRING ##
msgPrint -INFO "Please select your authentication method from the following menu"
authOptions=("Username/Password" "Oracle Kerberos Authentication" "OS Authentication" "OS SYSDBA Authentication" "Oracle External Password Store (Wallet)" "Quit script")
PS3="Please select your option [1-${#authOptions[*]}]: "
select opt in "${authOptions[@]}"
do
# opt=$(whiptail --title "Authentication Method" --menu "Select your authenticationn method" 25 90 16 \
# "Username/Password" "Use a standard DB account and password" \
# "Kerberos Ticket" "Use a Kerberos ticket for accessing the database" \
# "OS Authentication" "$(whoami) must have configured OS Authentication " \
# "OS SYSDBA Authentication" "Login with '/ as sysdba'" \
# "Oracle External Password Store" "Login using an external wallet file" \
# "Quit" "Exit this script now")

	case ${opt} in
		("Username/Password")
			msgPrint -input "Please enter your DBA account username"
			read dbUser
			msgPrint -input "Please enter your DBA account password"
			stty -echo
			read dbPswd
			stty echo
			export loginCreds="${dbUser}/${dbPswd}"
			break;;
		("Oracle Kerberos Authentication")
			msgPrint -notice "Checking Kerberos Ticket..."
			oklist > ${TEMPDIR}/_oklist_$$.out 2>&1
			if [[ -z $(cat ${TEMPDIR}/_oklist_$$.out | grep "krbtgt/ENT.WFB.BANK.CORP@ENT.WFB.BANK.CORP") ]]
			then
				msgPrint -warning "No Kerberos credentials found"
				msgPrint -info "Please input your kerberos password when prompted"
				stty -echo
				enable_kerberos
				stty echo
			else
				msgPrint -notice "Kerberos credentials found"
			fi
			rm -f  ${TEMPDIR}/_oklist_$$.out
			export loginCreds="/"
			break;;
		("OS Authentication")
			msgPrint -warning "Please make sure you're logged as an authorized OS user on the database"
			export loginCreds="/"
			break;;
		("OS SYSDBA Authentication")
			msgPrint -warning "Please make sure you're logged as an authorized SYSDBA user on the database (i.e. oracle)"
			loginCreds="/"
			asSysdba=" as sysdba"
			break;;
		("Oracle External Password Store (Wallet)")
			if [[ -z ${TNS_ADMIN} ]]
			then
				msgPrint -input "Please enter the TNS_ADMIN location that points to the External Password Store"
				read TNS_ADMIN
				export TNS_ADMIN
			else
				msgPrint -notice "TNS_ADMIN set to ${TNS_ADMIN}"
			fi
			export loginCreds="/"
			break;;
		("Quit script")
			msgPrint -none "Thanks for using this script! See you soon"
			exit;;
		(?)
			msgPrint -error "Invalid option, please try again"
			;;
	esac
done



## CREATE TEMPORARY LOCATION FOR THE REPORTS ##
msgPrint -notice "Checking temporary file locations"
if [[ -d ${TEMPDIR}/AWR_Report ]]
then
	msgPrint -info "AWR Reports temporary directory found"
else
	mkdir ${TEMPDIR}/AWR_Report
	msgPrint -info "AWR Reports temporary directory created"
fi
if [[ -d ${TEMPDIR}/ADDM_Report ]]
then
	msgPrint -info "ADDM Reports temporary directory found"
else
	mkdir ${TEMPDIR}/ADDM_Report
	msgPrint -info "ADDM Reports temporary directory created"
fi
rm -f ${TEMPDIR}/AWR_Report/*
rm -f ${TEMPDIR}/ADDM_Report/*
msgPrint -blank

## CHECK REPORTS REQUESTED ##
if [[ -z ${ADDM} && -z ${AWR} ]]
then
	msgPrint -notice "No reports specified, generating full set"
	ADDM=1
	AWR=1
else
	if [[ -z ${ADDM} ]]
	then
		ADDM=0
	fi
	if [[ -z ${AWR} ]]
	then
		AWR=0
	fi
fi

## REQUIRED INPUTS ##
msgPrint -title "REQUIRED INPUTS"
if [[ -z ${database} ]]
then
	msgPrint -input "Please enter database name"
	read database
fi
msgPrint -blank
msgPrint -notice "Checking email address"
if  [[ -n ${email_to} && $(echo ${email_to} | egrep -q "^[A-Za-z0-9._]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,4}$") -eq 0 ]]
then
	validEmail=1
else
	validEmail=0
fi
if [[ ${validEmail} -eq 0 ]]
then
	validEmail=0
	while [[ ${validEmail} -ne 1 ]]
	do
		msgPrint -input "Please enter the email address to send the reports"
		read email_to
		if  [[ -n ${email_to} && $(echo ${email_to} | egrep -q "^[A-Za-z0-9._]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,4}$") -eq 0 ]]
		then
			validEmail=1
			msgPrint -notice "Email validated"
		else
			validEmail=0
			msgPrint -error "Malformed email, please try again."
		fi
	done
fi
## Create temp file for storing runtime data
export RUNFILE=${TEMPDIR}/_awr_addm_reports_${database}.tmp

msgPrint -debug "MAIN:$LINENO" "Login Credentials: ${loginCreds}@${database}${asSysdba}"
if [[ ${DEBUG} -eq 1 ]]
then
	continueQuestion
fi

## CHECKING FOR PREVIOUS RUN DATA ##
if [[ -e ${RUNFILE} ]]
then
	msgPrint -info "Information from last run found!"
	counter=1
	while read line
	do
		if [[ ${counter} -eq 1 ]]
		then
				startTime=${line}
		elif [[ ${counter} -eq 2 ]]
		then
				endTime=${line}
		elif [[ ${counter} -eq 3 ]]
		then
				startSnap=${line}
		elif [[ ${counter} -eq 4 ]]
		then
				startSnapTime=${line}
		elif [[ ${counter} -eq 5 ]]
		then
				endSnap=${line}
		elif [[ ${counter} -eq 6 ]]
		then
				endSnapTime=${line}
		elif [[ ${counter} -eq 7 ]]
		then
				database=${line}
		elif [[ ${counter} -eq 8 ]]
		then
				dbid=${line}
		elif [[ ${counter} -eq 9 ]]
		then
				instances=${line}
		fi
		(( counter+=1 ))
	done < ${RUNFILE}
	msgPrint -blank
	msgPrint -info "START TIME is ${startSnap} taken at ${startSnapTime}"
	msgPrint -info "END TIME is ${endSnap} taken at ${endSnapTime}"
	msgPrint -info "The database name is: ${database}"
	msgPrint -info "The DBID for the database is: ${dbid}"
	msgPrint -info "There are ${instances} instances in this cluster"

	msgPrint -input "Do you want to use these values? (y/n)"
	answer="a"
	while [[ ${answer} != "y" && ${answer} != "Y" && ${answer} != "n" && ${answer} != "N" ]]
	do
		read answer
		if [[ ${answer} = "y" || ${answer} = "Y" ]]
		then
			msgPrint -blank
			msgPrint -info "Using previous run data..."
			msgPrint -blank
			previous=1
		elif [[ ${answer} = "n" || ${answer} = "N" ]]
		then
			previous=0
			msgPrint -blank
			msgPrint -input "Please enter database name"
			read database
## TIMESTAMPS INPUTS ##
			readTimestamps
		else
			msgPrint -input "Unrecognized input, please type 'y' or 'n'"
		fi
	done
else
	msgPrint -info "No information from last run found!"
	readTimestamps
fi

msgPrint -debug "MAIN:$LINENO" "database: ${database}"

if [[ ${DEBUG} -eq 1 ]]
then
	continueQuestion
fi

## GETTING ADDITIONAL REQUIRED INFO ##
if [[ ${ADDM} -eq 1 || ${AWR} -eq 1 ]]
then
	if [[ ${previous} -eq 0 ]]
	then
	## Get start snapshot number
		msgPrint -info "Looking for the starting snapshot... "
		tempSnap=0
		getSnapNumber start ${startTime} #> /dev/null 2>&1
		startSnap=${tempSnap}
		msgPrint -notice "Found!: ${startSnap}"
		## Get start snapshot time
		msgPrint -info "Looking for the starting snapshot timestamp... "
		getSnapTime start ${startSnap} #> /dev/null 2>&1
		startSnapTime=${tempSnapTime}
		msgPrint -notice "Found!: ${startSnapTime}"
		msgPrint -info "Start Snapshot: ${startSnap} - Start time: ${startSnapTime}"
		## Get end snapshot number
		msgPrint -info "Looking for the ending snapshot... "
		tempSnap=0
		getSnapNumber end ${endTime} #> /dev/null 2>&1
		endSnap=${tempSnap}
		msgPrint -notice "Found!: ${endSnap}"
		## Get end snapshot time
		msgPrint -info "Looking for the ending snapshot time... "
		getSnapTime end ${endSnap} #> /dev/null 2>&1
		endSnapTime=${tempSnapTime}
		msgPrint -notice "Found!: ${endSnapTime}"
		msgPrint -info "End Snapshot: ${endSnap} - End time: ${endSnapTime}"
		## Get the DB Name
		msgPrint -info "Fetching DB Name... "
		getDBName #> /dev/null 2>&1
		msgPrint -notice "Found!"
		msgPrint -info "Database Name: ${database}"
		## Get the DBID
		msgPrint -info "Fetching Database DBID... "
		getDBID #> /dev/null 2>&1
		msgPrint -notice "Found!"
		msgPrint -info "DBID: ${dbid}"
		## Get the number of instances
		msgPrint -info "Fetching Number of instances... "
		getNumberOfInstances #> /dev/null 2>&1
		msgPrint -notice "Found!"
		msgPrint -info "Number of instances in this cluster: ${instances}"
		msgPrint -blank
		msgPrint -blank
		msgPrint -separator
		msgPrint -plain "###   INFORMATION REVIEW   ###"
		msgPrint -separator
		msgPrint -blank
		msgPrint -info "The closest snapshot found for the START TIME is ${startSnap} taken at ${startSnapTime}"
		msgPrint -info "The closest snapshot found for the END TIME is ${endSnap} taken at ${endSnapTime}"
		msgPrint -info "The database name for this script is: ${database}"
		msgPrint -info "The DBID for the database is: ${dbid}"
		msgPrint -info "There are ${instances} instances in ${database} cluster"
		msgPrint -blank
	fi
	## Continue?
	continueQuestion
	msgPrint -blank
	msgPrint -blank
fi
msgPrint -debug "MAIN:$LINENO" "database: ${database}"

## SAVING RUN DATA ##
msgPrint -notice "Saving runtime data"
echo ${startTime} > ${RUNFILE}
echo ${endTime} >> ${RUNFILE}
echo ${startSnap} >> ${RUNFILE}
echo ${startSnapTime} >> ${RUNFILE}
echo ${endSnap} >> ${RUNFILE}
echo ${endSnapTime} >> ${RUNFILE}
echo ${database} >> ${RUNFILE}
echo ${dbid} >> ${RUNFILE}
echo ${instances} >> ${RUNFILE}

## GENERATING AWR REPORTS ##
if [[ ${AWR} -eq 1 ]]
then
    profiling start "${database}_AWR_Reports"
	msgPrint -separator
	msgPrint -notice "Generating AWR Report for ${database} database"
## AWR Reports ##
        msgPrint -notice "Changing to AWR temporary directory..."
        cd ${TEMPDIR}/AWR_Report
        msgPrint -blank
## Create Global AWR Report ##
        msgPrint -notice "Generating Global AWR Report, please wait..."
        reportName="awr_${database}_${startSnap}_${endSnap}_report.html"
        generateAWRGlobalReport ${database} ${dbid} ${startSnap} ${endSnap} > /dev/null 2>&1
        msgPrint -notice "Report awr_${database}_${startSnap}_${endSnap}_report.html created!"
        counter=1
        while [[ ${counter} -le ${instances} ]]
        do
                instName="${database}${counter}"
## Create instance-level AWR Reports ##
                msgPrint -notice "Generating Instance AWR Report for $instName, please wait..."
                reportName="awr_${instName}_${startSnap}_${endSnap}_report.html"
                generateAWRInstanceReport ${database} ${dbid} ${counter} ${instName} ${startSnap} ${endSnap} > /dev/null 2>&1
                msgPrint -notice "Report awr_${instName}_${startSnap}_${endSnap}_report.html created!"
        (( counter+=1 ))
        done

        zip -T9 AWR_${database}_${startSnap}_${endSnap}_REPORT.zip awr*
        if [[ $? -eq 0 ]]
        then
                rm -f awr*report.html
        else
                print "[WARNING] There was a problem compressing the files, please go ahead from here manually"
                msgPrint -notice "Files are located in ${TEMPDIR}/AWR_Report"
        fi
    profiling stop "${database}_AWR_Reports"
fi

## GENERATING ADDM REPORTS ##
if [[ ${ADDM} -eq 1 ]]
then
	profiling start "${database}_ADDM_Reports"
	msgPrint -separator
	msgPrint -notice "Generating ADDM Report for ${database} database"
	msgPrint -notice "Changing to ADDM temporary directory..."
	cd ${TEMPDIR}/ADDM_Report
	print ""

	counter=1
	while [[ ${counter} -le ${instances} ]]
	do
			instName="database${counter}"
## Create instance-level ADDM Reports ##
			msgPrint -notice "Generating Instance ADDM Report for $instName, please wait..."
			REPORTNAME="addm_${instName}_${STARTSNAP}_${ENDSNAP}_report.txt"
			generateADDMInstanceReport ${database} ${dbid} ${counter} ${instName} ${startSnap} ${endSnap} > /dev/null 2>&1
			msgPrint -notice "Report addm_${instName}_${startSnap}_${endSnap}_report.txt created!"
	(( counter+=1 ))
	done

	zip -T9 ADDM_${database}_${startSnap}_${endSnap}_REPORT.zip addm*
	if [[ $? -eq 0 ]]
	then
			rm -f addm*report.txt
	else
			print "[WARNING] There was a problem compressing the files, please go ahead from here manually"
			msgPrint -notice "Files are located in ${TEMPDIR}/ADDM_Report"
	fi
	profiling stop "${database}_ADDM_Reports"
fi

profiling stop "awr_addm_reports_profile_$$"
setupLogs stop ${logFile}

if [[ -n ${email_to} ]]
then
export timeStamp=$(date +"%Y%m%d")
export hostName=$(hostname)
email_to="${email_to}"
email_from="$(whoami)@${hostName}"
if [[ $AWR -eq 1 && $ADDM -eq 1 ]]
then
        subject="ADDM and AWR Reports for ${database}: ${startSnapTime} to ${endSnapTime} (UTC)"
        email_msg="ADDM AND AWR Reports Generated by awr_addm_reports.sh script</br>
==========================================================================</br>
</br>
<p>For ADDM and AWR reports, please open the attached ZIP files</p>"
elif [[ $AWR -eq 1 && $ADDM -eq 0 ]]
then
        subject="AWR Reports for ${database}: ${startSnapTime} to ${endSnapTime} (UTC)"
        email_msg="AWR Reports Generated by awr_addm_reports.sh script</br>
==========================================================================</br>
</br>
<p>For AWR reports, please open the attached ZIP file</p>"
elif [[ $AWR -eq 0 && $ADDM -eq 1 ]]
then
        subject="ADDM Reports for ${database}: ${startSnapTime} to ${endSnapTime} (UTC)"
        email_msg="ADDM Reports Generated by awr_addm_reports.sh script</br>
==========================================================================</br>
</br>
<p>For ADDM reports, please open the attached ZIP file</p>"
fi
email_msg="${email_msg}
</br>
Thank you for using this script.</br>
</br>
For troubleshooting, pelase contact jsanchez.consultant@gmail.com</br>
"

( cat <<- _EOF_
From: ${email_from}
To: ${email_to}
Subject: ${subject}
Date: $(date +%Y%m%d)
Return-Path: ${email_to}
MIME-Version: 1.0
Content-Type: multipart/mixed; boundary="-$MAILPART"
---$MAILPART
Content-Type: text/html
Content-Disposition: inline

${email_msg}

_EOF_

if [[ ${AWR} -eq 1 ]]
then
cat <<_EOF_
---$MAILPART
Content-type: application/zip; name="AWR_${COD}_${startSnap}_${endSnap}_REPORT.zip"
Content-Transfer-Encoding: base64
Content-Disposition: attachment; filename="AWR_${database}_${startSnap}_${endSnap}_REPORT.zip"
_EOF_
/usr/bin/uuencode -m ${TEMPDIR}/AWR_Report/AWR_${database}_${startSnap}_${endSnap}_REPORT.zip AWR_${database}_${startSnap}_${endSnap}_REPORT.zip
fi
if [[ ${ADDM} -eq 1 ]]
then
cat <<_EOF_
---$MAILPART
Content-type: application/zip; name="ADDM_${database}_${startSnap}_${endSnap}_REPORT.zip"
Content-Transfer-Encoding: base64
Content-Disposition: attachment; filename="ADDM_${database}_${startSnap}_${endSnap}_REPORT.zip"
_EOF_

/usr/bin/uuencode -m ${TEMPDIR}/ADDM_Report/ADDM_${database}_${startSnap}_${endSnap}_REPORT.zip ADDM_${database}_${startSnap}_${endSnap}_REPORT.zip

fi
cat <<_EOF_

Regards.
---$MAILPART--
_EOF_
) | /usr/lib/sendmail -oi -t #> /dev/null 2>&1
fi
msgPrint -notice " Email sent to: $email_to"

find $TEMPDIR -name '*.log' -mtime +1 | xargs -r rm -f
find $TEMPDIR -name '*.tmp' -mtime +1 | xargs -r rm -f
find $TEMPDIR -name 'fifo.*' -mtime +1 | xargs -r rm -f
