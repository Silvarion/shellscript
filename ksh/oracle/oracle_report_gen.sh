#!/usr/bin/ksh

###########################
##
##      File: oracle_report_gen.sh
##
##      Author: Jesus Sanchez (jsanchez.consultant@gmail.com)
##
##	Copyright Notice: Creative Commons Attribution-ShareAlike 4.0 International License
##
##      How to run: oracle_report_gen.sh [-v] {-d <DBNAME>|--dbfile <DB LIST FILE>} [--dba <DBA_USER>] {-c <COMMAND> | -s <SQL_FILE_PATH>} -m <EMAIL_ADDRESSES> --subject <EMAIL_SUBJECT>
##
######################################################################


###############
## FUNCTIONS ##
###############

#####################
# Utility Functions #
#####################

# Setting environment variables
# Launch directory
export LAUNCHDIR=$(pwd)
# Source (script) directory
export SOURCEDIR=$( cd -P -- "$(dirname -- "$(command -v -- "$0")")" && pwd -P )
# Support scripts
source $SOURCEDIR/utility_functions.sh
source $SOURCEDIR/oracle_utilities.sh
# Temporary directory check
if [[ -d $SOURCEDIR/tmp ]]
then
        mkdir -p $SOURCEDIR/tmp
fi
export TEMPDIR=$SOURCEDIR/tmp

##########################
#
#       Function name: printUsage
#
#       Description:
#               This function prints the help about using this script
#
#       Usage: printUsage
#
##############################################
function printUsage {
        msgPrint -title HELP
        msgPrint -blank
        msgPrint -none "Usage: oracle_report_gen.sh [-v] {-d <DBNAME>|-f <DB LIST FILE>} [--dba <DBA_USER>] {-c <COMMAND> | -s <SQL_FILE_PATH>} -m <EMAIL_ADDRESSES> --subject <EMAIL_SUBJECT>"
        msgPrint -none "OPTIONS:"
        msgPrint -none "        -v|--verbose : Verbose mode. Activates debugging messages."
		msgPrint -none "		--attach : Attach the HTML output as a separate file as well"
        msgPrint -none "        -d|--database : Database. Need to provide the database name after this option."
		msgPrint -none "        ---dbfile : Path to file with the list of database names to query"
        msgPrint -none "        --dba : DBA username to connect to the database"
        msgPrint -none "        -c|--command : query to be executed to generate the report"
        msgPrint -none "        -s|--script : SQL File. Full path to the file that contains the sql query (queries) to be executed"
        msgPrint -none "        -m|--mail : Email address to send the log to."
        msgPrint -none "        -t|--tns : TNS_ADMIN export option"
        msgPrint -none "        --manual-html: Disables the MARKUP HTML option to allow constructing the HTML table directly on the query"
		msgPrint -none "        --test: Test mode. Avoids any database changing actions to be performed."

}

####################
## MAIN ALGORITHM ##
####################

# Settnig up the log file
logFile=$TEMPDIR/_oracle_report_gen_$$.log
setupLogs start $logFile

msgPrint -title "Welcome to the oracle_report_gen Script"

#Setting up profiling to gather running time.
profiling start "oracle_report_gen_profile_$$"

# Variables
export TEST=0
export DEBUG=0
export SILENT=0
noBlankReport=0
email_to=""
database=""
databaseList=""
typeset -u dbaUser
instanceName=""
manualHTML="SET MARKUP HTML ON ENTMAP OFF"
sendAttached=0


if [[ $# -gt 0 ]]
then
        # Categorize arguments
        . getArgs $*

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
                        ("--attach")
                                msgPrint -info "Attachment mode: ON"
                                sendAttached=1
                                ;;
                        ("-c"|"--command")
                                msgPrint -info "Running in COMMAND MODE!"
                                command=${GA_VALUES[$counter]}
                                msgPrint -debug "MAIN:$LINENO" "Command: $command"
                                runMode="COMMAND"
                                ;;
                        ("-d"|"--databases")
                                msgPrint -info "Found database list parameter"
                                databaseList=${GA_VALUES[$counter]}
                                msgPrint -debug "Database List: $databaseList"
                                ;;
                        ("-s"|"--script")
                                msgPrint -info "Running in SCRIPT/FILE MODE!"
                                fileName=${GA_VALUES[$counter]}
                                runMode="SCRIPT"
                                ;;
                        ("--dba")
                                dbaUser=${GA_VALUES[$counter]}
                                msgPrint -info "Using ${dbaUser} to connect to database(s)"
                                msgPrint -notice "You'll be prompted for the password soon"
                                ;;
                        ("-f" | "--file")
                                databaseFile=${GA_VALUES[$counter]}
                                msgPrint -info "File parameter found: $databaseFile"
                                databaseList=$(cat ${databaseFile} | tr '\r\n' ' ')
                                msgPrint -info "Database parameter found in file:
$databaseList"
                                ;;
                        ("--local")
                                msgPrint -info "Local mode found"
                                localMode=1
                                ;;
                        ("--manual-html")
                                msgPrint -info "Using Query HTML instead of the databases Markup option"
                                manualHTML=""
                                ;;
                        ("-m" | "--mail")
                                email_to=${GA_VALUES[$counter]}
                                msgPrint -info "Email parameter found: $email_to"
                                ;;
                        ("--noblank")
                                noBlankReport=1
                                msgPrint -info "Not sending blank reports"
                                ;;
                        ("-u" | "--user")
                                userList=${GA_VALUES[$counter]}
                                msgPrint -info "User parameter found: $userList"
                                ;;
                        ("-t" | "--tns")
                                TNS_ADMIN=${GA_VALUES[$counter]}
                                msgPrint -info "TNS directory parameter found: $TNS_ADMIN"
                                export TNS_ADMIN
                                ;;
                        ("--subject")
                                subject=${GA_VALUES[$counter]}
                                msgPrint -info "Email subject found"
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

# Report Header and Footer - Begin
reportHeader="<html>
<head>
<style type='text/css'>
body {font:bold 10pt Arial,Helvetica,sans-serif; color:black; background:White;}
p {font:bold 10pt Arial,Helvetica,sans-serif; color:black; background:White;}
table {font:bold 10pt Arial,Helvetica,sans-serif; color:Black; background:#f7f7e7; padding:0px 0px 0px 0px; margin:0px 0px 0px 0px; }
tr,td {font:bold 10pt Arial,Helvetica,sans-serif; color:Black; background:#f7f7e7; padding:0px 0px 0px 0px; margin:0px 0px 0px 0px;}
th {font:bold 10pt Arial,Helvetica,sans-serif; color:blue; background:#cccc99; padding:0px 0px 0px 0px; }
h1 {font:16pt Arial,Helvetica,Geneva,sans-serif; color:#336699; background-color:White; border-bottom:1px solid #cccc99; margin-top:0pt; margin-bottom:0pt; padding:0px 0px 0px 0px;}
h2 {font:bold 10pt Arial,Helvetica,Geneva,sans-serif; color:#336699; background-color:White; margin-top:4pt; margin-bottom:0pt;}
a {font:9pt Arial,Helvetica,sans-serif; color:#663300; background:#ffffff; margin-top:0pt; margin-bottom:0pt; vertical-align:top;}
.normal-row {font:bold 10pt Arial,Helvetica,sans-serif; color:Black; background:#f7f7e7; padding:0px 0px 0px 0px; margin:0px 0px 0px 0px; }
.threshold-critical { font:bold 10pt Arial,Helvetica,sans-serif; color:yellow; background-color:red; display:block; }
.threshold-warning { background-color:orange; display:block; }
.threshold-watch { background-color:yellow; display:block; }
.total-critical { font:bold,italic 12pt Arial,Helvetica,sans-serif; color:yellow; background-color:red; display:block; }
.total-warning { font:bold,italic 12pt Arial,Helvetica,sans-serif; color:black; background-color:orange; display:block; }
.total-watch { font:bold,italic 12pt Arial,Helvetica,sans-serif; color:black; background-color:yellow; display:block; }
.total-row { font:normal,italic 12pt Arial,Helvetica,sans-serif; color:black; text-align:right; display:block; }
.threshold-critical-num { font:bold 10pt Arial,Helvetica,sans-serif; color:yellow; background-color:red; text-align:right; display:block; }
.threshold-warning-num { background-color:orange; text-align:right; display:block; } 
.threshold-watch-num { background-color:yellow; text-align:right; display:block; }
.total-critical-num { font:bold,italic 12pt Arial,Helvetica,sans-serif; color:yellow; background-color:red; text-align:right; display:block; }
.total-warning-num { font:bold,italic 12pt Arial,Helvetica,sans-serif; color:black; background-color:orange; text-align:right; display:block; }
.total-watch-num { font:bold,italic 12pt Arial,Helvetica,sans-serif; color:black; background-color:yellow; text-align:right; display:block; }
.normal-row-num {font:bold 10pt Arial,Helvetica,sans-serif; color:Black; background:#f7f7e7; padding:0px 0px 0px 0px; margin:0px 0px 0px 0px; text-align:right; display:block; }
.total-row-num { font:normal,italic 12pt Arial,Helvetica,sans-serif; color:black; text-align:right; display:block; }
</style>
</head>
<body>
<p>Databases used for this report: ${databaseList}</P>

"
reportTS=$(date +"%d-%h-%Y %H:%M:%S")
reportFooter="
Report Time: ${reportTS} as in $(hostname) TZ
</html>"

# Report Header and Footer - End

# Required information input

# Set login credentials - Begin
if [[ ${localMode} -eq 0 || -z ${TNS_ADMIN} ]]
then
        if [[ -z ${dbaUser} || -z ${dbaPass} ]]
        then
                msgPrint -none "DB Credentials Required"
                msgPrint -blank
				# Special users (REPORTUSER and SYS)
                if [[ ${dbaUser} = "<DEFAULT USER>" ]]
                then
                        dbaPass="<DEFAULT USER PASSWORD>"
                elif [[ ${dbaUser} = "SYS" ]]
                then
                        asSysdba="as sysdba"
				# Other DBA usernames
                elif [[ -z ${dbaUser} ]]
                then
                        msgPrint -input "Please enter the DB username to be used"
                        read dbaUser
                else
                        msgPrint -info "Using Database User: ${dbaUser}"
                fi
                if [[ -z ${dbaPass} ]]
                then
                        msgPrint -input "Please enter the password for ${dbaUser} user"
                        stty -echo
                        read dbaPass
                        stty echo
                fi
                msgPrint -blank
        fi
		# Build authorization string (username/password)
        authString="$dbaUser/$dbaPass"
else
        authString="/"
        asSysdba="as sysdba"
fi
# Set login credentials - End

# Set command to run - Begin

                # Checking run mode and setting run line
msgPrint -debug "MAIN:$LINENO" "Looking for running mode"
case $runMode in
        ("COMMAND")
                msgPrint -debug "MAIN:$LINENO" "Command mode ON"
                toRun="$command"
                ;;
        ("SCRIPT")
                msgPrint -debug "MAIN:$LINENO" "Script/File mode ON"
                toRun="@$fileName"
                ;;
        (?)
                msgPrint -debug "MAIN:$LINENO" "Run mode not properly set, please try again"
                printUsage
                exit 1
                ;;
esac
# Set command to run - End

# Cycle through databases
spoolFile=$TEMPDIR/oracle_report_gen_spool_$$.tmp
for database in $databaseList
do
	# Start the output clean
	tempOutput=""
	# Test the database for connectivity
	msgPrint -info "Probing ${database} database"
	(tnsping ${database}) > /dev/null 2>&1
	if [[ $? -eq 0 ]]
	then
		msgPrint -info "Probe successful. Connecting!"
		# Run the query
		sqlplus -s >${spoolFile}<<_EOSQL_
${authString}@${database} ${asSysdba}
set echo off
${manualHTML}
set pagesize 999
set linesize 180
set feedback off
${toRun}
PROM
exit
_EOSQL_
		msgPrint -info "Done"
		# Clean the output
		msgPrint -debug "MAIN:$LINENO" "Spool file contents
		
		$(cat ${spoolFile})"
		tempOutput=$(cat ${spoolFile} | grep -v spool)
		commonRows=$(cat ${spoolFile} | grep -v spool | grep -vi "no rows selected" | grep -vi "${database}" | grep -Ev "</{0,1}[a-z]*>" | grep -vi "table border" |tr -d [:space:])
		msgPrint -debug "MAIN:$LINENO" "Common Rows: ${commonRows}"
		rm -f ${spoolFile}
	else
		msgPrint -critical "Can't connect to ${database} database, please contact the Primary DBA"
		tempOutput="Couldn't connect to ${database}"
	fi
# Concat the output for each database
if [[ ${noBlankReport} -eq 1 ]]
then
	if [[ -z "${commonRows}"  ]]
	then
		msgPrint -notice "Empty report detected"
	else
		tempHTML="${tempHTML}
${tempOutput}"
	fi
else
	tempHTML="${tempHTML}
${tempOutput}"
fi
done

# Build the full HTML report
htmlOutput="${reportHeader}
${tempHTML}
${reportFooter}"

tempHTMLFile=${TEMPDIR}/htmlFile_$$.tmp

echo -ne "${tempHTML}" > ${tempHTMLFile}

echo -e "${htmlOutput}" > ${TEMPDIR}/report_output_$$.html

# Stopping profiling
profiling stop "oracle_report_gen_profile_$$"
# Stopping logs
setupLogs stop $logFile

# Email check
if [[ -n ${email_to} && -n ${tempHTML} ]]
then
export timeStamp=$(date +"%Y%m%d")
export hostName=$(hostname)
MAILPART=$(/usr/bin/uuidgen)
subject="[REPORT] ${subject}"
email_to="${email_to}"
email_from="Oracle Report Generator @${hostName}"
email_msg="${htmlOutput}
--
Thanks for using this script.
--
For troubleshooting, please contact jsanchez.consultant@gmail.com"
(cat <<- _EOF_ 
From: $email_from
To: $email_to
Subject: $subject
Date: $(date +%Y%m%d)
Return-Path: ${email_to}
MIME-Version: 1.0
Content-Type: multipart/mixed; boundary="-$MAILPART"
---$MAILPART
Content-Type: text/html
Content-Disposition: inline
$email_msg
_EOF_

# Check if attachments are required
	if [ ${sendAttached} -eq 1 ]
	then
	cat <<_EOF_
---$MAILPART
Content-type: application; name="report_output_$$.html"
Content-Transfer-Encoding: base64
Content-Disposition: attachment; filename="report_output_$$.html"
_EOF_

# Encoding the HTML in case of asking for it as an attachment
echo -ne "${htmlOutput}" | base64 

cat <<_EOF_

---$MAILPART--
_EOF_
	fi ) | /usr/lib/sendmail -oi -t
fi

# Cleanup the mess
rm -f $TEMPDIR/report_output_$$.html ${tempHTMLFile}
find $TEMPDIR/_oracle_report_gen*.log -mtime +14 | xargs -r rm -f
