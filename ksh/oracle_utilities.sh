#!/usr/bin/ksh

###########################
##
##	File: oracle_utilities.sh
##
##	Author: Jesus Sanchez (jsanchez.consultant@gmail.com)
##
##	Copyright Notice: Creative Commons Attribution-ShareAlike 4.0 International License
##
##	Sample run: . oracle_utilities.sh
##
######################################################################


##################################
##
##	Function: getHosts
##
##	Description:
##		This function returns an space separated list
##	of hostnames associated with instances of the database
##
##	Pre-requisites: Oracle environment must have been set
##
##	Usage: <VARIABLE>=getHosts <LOGIN STRING>
##
#####################################################
function getHosts {
	loginString=${1}
	#Setting the spool file
	spoolFile=$TEMPDIR/${database}_hosts_$$.tmp
	if [[ -z ${loginString} ]]
	then
		loginString="/ as sysdba"
	fi
	(sqlplus ${loginString}<<_EOSQL_
	set pagesize 0
	set heading off
	set feedback off
	set echo off
	spool $spoolFile
	SELECT host_name FROM gv\$instance order by 1;
	spool off
	exit
_EOSQL_
) > /dev/null 2>&1
	#Cleaning the output
	hostList=$(cat ${spoolFile} |grep -v ">" | grep -v SELECT | grep -v exit | tr -s [:space:])
	#Return the output
	echo "${hostList}"
	#Clean temporary files
	rm -f ${spoolFile}
	return 0
}

##################################
##
##	Function: getInstance
##
##	Description:
##		This function returns the instance name associated
##	with the hostname provided as argument
##
##	Pre-requisites: Oracle environment must have been set
##
##	Usage: <VARIABLE>=getInstance <DATABASE> <LOGIN STRING>
##
#####################################################
function getInstance {
	database=${1}
	loginString=${2}
	spoolFile=$TEMPDIR/${database}_inst_$$.tmp
	if [[ -z ${loginString} ]]
	then
		loginString="/ as sysdba"
	fi
	(sqlplus ${loginString}<<_EOSQL_
	set pagesize 0
	set heading off
	set feedback off
	set echo off
	spool $spoolFile
	SELECT instance_name FROM v\$instance;
	spool off
	exit
_EOSQL_
) > /dev/null 2>&1
	instName=$(cat ${spoolFile} |grep -v ">" | grep -v SELECT | grep -v exit | tr -s [:space:])
	# msgPrint -debug "oracle_utilities.sh:getInstance:$LINENO" "Echoing variable"
	echo "$instName"
	rm $spoolFile
	return 0
}

##################################
##
##	Function: getInstanceForHost
##
##	Description:
##		This function returns the instance name associated
##	with the hostname provided as argument
##
##	Pre-requisites: Oracle environment must have been set
##
##	Usage: <VARIABLE>=getInstanceForHost <HOSTNAME> <DATABASE> <LOGIN_STRING>
##
#####################################################
function getInstanceForHost {
	DEBUG=0
	hostName=$1
	database=$2
	loginString=$3
	spoolFile=$TEMPDIR/${database}_inst4host_$$.tmp
	if [[ -z ${loginString} ]]
	then
		loginString="/ as sysdba"
	fi
	
	if [[ -n $database ]]
	then
		setOracleEnvironment $database
	fi
	(sqlplus ${loginString}<<_EOSQL_
	set pagesize 0
	set heading off
	set feedback off
	set echo off
	spool $spoolFile
	SELECT instance_name FROM gv\$instance WHERE host_name='${hostName}';
	spool off
	exit
_EOSQL_
) > /dev/null 2>&1
	instName=$(cat ${spoolFile} |grep -v ">" | grep -v SELECT | grep -v exit | tr -s [:space:])
	# msgPrint -debug "oracle_utilities.sh:getHosts:$LINENO" "Echoing variable"
	echo "$instName"
	rm $spoolFile
	return 0
}

##################################
##
##	Function: getDataName
##
##	Description:
##		This function returns the name of the data disk group
##	as in the database parameter "db_create_file_dest"
##
##	Pre-requisites: Oracle environment must have been set
##
##	Usage: <VARIABLE>=getDataName <DATABASE> <LOGIN STRING>
##
#####################################################
function getDataName {
	DEBUG=0
	database=$1
	loginString=$2
if [[ -z $database && -z $ORACLE_SID ]]
	then
		echo "No Database Defined"
	else
		spoolFile=$TEMPDIR/data_name_$$.tmp
	if [[ -z ${loginString} ]]
	then
		loginString="/ as sysdba"
		setOracleEnvironment $database
	fi
	(sqlplus ${loginString}<<_EOSQL_
set pagesize 0
set heading off
set feedback off
set echo off
spool $spoolFile
SELECT value "VALUE" FROM v\$spparameter WHERE name='db_create_file_dest';
spool off;
exit
_EOSQL_
) > /dev/null 2>&1
		if [[ $? -eq 0 ]]
		then
			dataName=$(cat ${spoolFile} | grep -vi SELECT | grep -vi FROM | grep -vi WHERE | grep -vi spool | grep -v ">" | tr -s [:space:] | tr -d "+")
			rm -f ${spoolFile}
			echo $dataName
		else
			echo "Connection issues"
			return -1
		fi
	fi
}

##################################
##
##	Function: getFraName
##
##	Description:
##		This function returns the name of the FRA disk group
##	as in the database parameter "db_recovery_file_dest"
##
##	Pre-requisites: Oracle environment must have been set
##
##	Usage: <VARIABLE>=getFraName <DATABASE> <LOGIN STRING>
##
#####################################################
function getFraName {
	DEBUG=0
	database=$1
	loginString=$2
	if [[ -z $database && -z $ORACLE_SID ]]
	then
		echo "No Database Defined"
	else
		spoolFile=$TEMPDIR/fra_name_$$.tmp
	if [[ -z ${loginString} ]]
	then
		loginString="/ as sysdba"
		setOracleEnvironment $database
	fi
	(sqlplus ${loginString}<<_EOSQL_
set pagesize 0
set heading off
set feedback off
set echo off
spool $spoolFile
SELECT value "VALUE" FROM v\$spparameter WHERE name='db_recovery_file_dest';
spool off;
exit
_EOSQL_
) > /dev/null 2>&1
		if [[ $? -eq 0 ]]
		then
			fraName=$(cat ${spoolFile} | grep -vi SELECT | grep -vi FROM | grep -vi WHERE | grep -vi spool | grep -v ">" | tr -d [:space:] | tr -d "+")
			rm -f ${spoolFile}
			echo $fraName
		else
			echo "Connection issues"
			return -1
		fi
	fi
}

#################################
##
##	Function: getFraQuota
##
##	Description:
##		This function returns the quota allowance of the FRA disk group
##	as in the database parameter "db_recovery_file_dest_size"
##
##	Pre-requisites: Oracle environment must have been set
##
##	Usage: <VARIABLE>=getFraQuota <DATABASE> <LOGIN STRING>
##
#####################################################
function getFraQuota {
	DEBUG=0
	database=$1
	loginString=$2
	if [[ -z $database && -z $ORACLE_SID ]]
	then
		echo "No Database Defined"
	else
		spoolFile=$TEMPDIR/fra_quota_$$.tmp
	if [[ -z ${loginString} ]]
	then
		loginString="/ as sysdba"
		setOracleEnvironment $database
	fi
	(sqlplus ${loginString}<<_EOSQL_
set pagesize 0
set heading off
set feedback off
set echo off
spool $spoolFile
SELECT value/1024/1024/1024 "VALUE" FROM v\$spparameter WHERE name='db_recovery_file_dest_size';
spool off;
exit
_EOSQL_
) > /dev/null 2>&1
		if [[ $? -eq 0 ]]
		then
			fraQuota=$(cat ${spoolFile} | grep -vi SELECT | grep -vi FROM | grep -vi WHERE | grep -vi spool | grep -v ">" | tr -d [:space:])
			rm -f ${spoolFile}
			echo ${fraQuota}
		else
			echo "Connection issues"
			return -1
		fi
	fi
}

#################################
##
##	Function: getUniqueName
##
##	Description:
##		This function returns the unique name of the database
## as in the column "DB_UNIQUE_NAME" at V$DATABASE
##
##	Pre-requisites: Oracle environment must have been set
##
##	Usage: <VARIABLE>=getUniqueName <DATABASE> <LOGIN STRING>
##
#####################################################
function getUniqueName {
	DEBUG=0
	database=$1
	loginString=$2
	if [[ -z $database && -z $ORACLE_SID ]]
	then
		echo "No Database Defined"
	else
		spoolFile=$TEMPDIR/dbUniqueName_$$.tmp
	if [[ -z ${loginString} ]]
	then
		loginString="/ as sysdba"
		setOracleEnvironment $database
	fi
	(sqlplus ${loginString}<<_EOSQL_
set pagesize 0
set heading off
set feedback off
set echo off
spool $spoolFile
SELECT DB_UNIQUE_NAME FROM v\$database;
spool off;
exit
_EOSQL_
) > /dev/null 2>&1
		if [[ $? -eq 0 ]]
		then
			dbUniqueName=$(cat ${spoolFile} | grep -vi SELECT | grep -vi FROM | grep -vi WHERE | grep -vi spool | grep -v ">" | tr -d [:space:])
			rm -f ${spoolFile}
			echo ${dbUniqueName}
		else
			echo "Connection issues"
			return -1
		fi
	fi
}

#################################
##
##	Function: getHostName
##
##	Description:
##		This function returns the name of the FRA disk group
##	as in the database column "HOST_NAME" from V$INSTANCE
##
##	Pre-requisites: Oracle environment must have been set
##
##	Usage: <VARIABLE>=getHostName <DATABASE> <LOGIN STRING>
##
#####################################################
function getHostName {
	DEBUG=0
	database=$1
	loginString=$2
	if [[ -z $database && -z $ORACLE_SID ]]
	then
		echo "No Database Defined"
	else
		spoolFile=$TEMPDIR/clusterName_$$.tmp
	if [[ -z ${loginString} ]]
	then
		loginString="/ as sysdba"
		setOracleEnvironment $database
	fi
	(sqlplus ${loginString}<<_EOSQL_
set pagesize 0
set heading off
set feedback off
set echo off
spool $spoolFile
select host_name from v\$instance;
spool off;
exit
_EOSQL_
) > /dev/null 2>&1
		if [[ $? -eq 0 ]]
		then
			clusterName=$(cat ${spoolFile} | grep -vi SELECT | grep -vi FROM | grep -vi WHERE | grep -vi spool | grep -v ">" | tr -d [:space:])
			rm -f ${spoolFile}
			echo ${clusterName}
		else
			echo "Connection issues"
			return -1
		fi
	fi
}

#################################
##
##	Function: getFileTypes
##
##	Description:
##		This function returns the file types in the diskgroup
## 	received as parameter
##
##	Pre-requisites: Oracle environment must have been set
##
##	Usage: <VARIABLE>=getFileTypes <DATABASE> <DISK GROUP> <LOGIN STRING>
##
#####################################################
function getFileTypes {
	DEBUG=0
	database=$1
	currentDG=$2
	loginString=$3
	if [[ -z $database && -z $ORACLE_SID ]]
	then
		echo "No Database Defined"
	else
		spoolFile=$TEMPDIR/fileTypes_$$.tmp
	if [[ -z ${loginString} ]]
	then
		loginString="/ as sysdba"
		setOracleEnvironment $database
	fi
	(sqlplus ${loginString}<<_EOSQL_
set pagesize 0
set heading off
set feedback off
set echo off
spool $spoolFile
select /*+RULE*/ distinct(c.type) from v\$asm_diskgroup b, v\$asm_file c where  b.group_number = c.group_number and b.name='${currentDG}';
spool off;
exit
_EOSQL_
) > /dev/null 2>&1
		if [[ $? -eq 0 ]]
		then
			fileTypes=$(cat ${spoolFile} | grep -vi SELECT | grep -vi FROM | grep -vi WHERE | grep -vi spool | grep -v ">" | tr -s [:space:])
			rm -f ${spoolFile}
			echo ${fileTypes}
		else
			echo "Connection issues"
			return -1
		fi
	fi
}


##################################
##
##      Function: getDatabaseSize
##
##      Description:
##              This function returns the used, allocated or total space
##      for the database which is set in the Oracle Environment
##
##      Pre-requisites: Oracle environment must have been set
##
##      Usage: <VARIABLE>=getDatabaseSize [-d <DBNAME>] [-g <DISK GROUP>] [-t USED|ALLOCATED|MAX|TOTAL] [--user <DB USER> --pswd <PASSWORD>]
##
#####################################################
function getDatabaseSize {
        typeset -u spaceType ## { USED | ALLOCATED | FREE |MAX | TOTAL }
        typeset -u diskGroup ## { DATA | FRA | FS}
        noFraOption=0
        file_type="N/A"
        if [[ $# -gt 0 ]]
        then
                # Categorize arguments
                . getArgs $* > /dev/null 2>&1

                # Process arguments and initialize variables
                counter=1
                for option in ${GA_OPTIONS[*]} # Values are in GA_VALUES
                do
                        case $option in
                                ("-d")
                                        database=${GA_VALUES[$counter]}
                                        #setOracleEnvironment ${database} > /dev/null 2>&1
                                        ;;
                                ("-f")
                                        fileType=${GA_VALUES[$counter]}
                                        ;;
                                ("-g")
                                        diskGroup=${GA_VALUES[$counter]}
                                        ;;
                                ("--no-fra")
                                        export noFraOption=1
                                        ;;
                                ("-t")
                                        spaceType=${GA_VALUES[$counter]}
                                        ;;
                                ("-v")
                                        DEBUG=1
                                        ;;
                                ("--user")
                                        dbUser=${GA_VALUES[$counter]}
                                        ;;
                                ("--pswd")
                                        dbPswd=${GA_VALUES[$counter]}
                                        ;;
                        esac
                        (( counter+=1 ))
                done
        fi
        # Argument processing done

if [[ -z ${dbUser} || -z ${dbPswd} ]]
then
        export loginString="/ as sysdba"
else
        export loginString="${dbUser}/${dbPswd}@${database}"
fi

## WORKFLOW START ##
        if [[ -z ${database} && -z ${diskGroup} && -z ${spaceType} ]] # No arguments
        then
                msgPrint -debug "MAIN:$LINENO" "Entering --> No arguments"
                if [[ -z ${ORACLE_HOME} || -z ${ORACLE_BASE} ]]
                then
                        echo -1
                        return 1
                else
                        query="SELECT (SELECT round(sum(f.file_size*t.blocksize/1024/1024/1024),2) USED_GB FROM v\$filespace_usage f, sys.ts\$ t WHERE t.ts#=f.tablespace_id)"
                        if [[ "${noFraOption}" -eq 1 ]]
                        then
                                msgPrint -debug "MAIN:$LINENO" "NO-FRA option"
                                query="${query}+(SELECT round(sum(bytes/1024/1024/1024),2) FROM v\$log) FROM dual"
                        else
                                msgPrint -debug "MAIN:$LINENO" "default option"
                                query="${query}+(SELECT round(sum(percent_space_used/100*${fraQuota}),2) FROM v\$recovery_area_usage WHERE file_type = ${fileType}) FROM dual"
                        fi
                fi
        elif [[ -n ${database} && -z ${diskGroup} && -z ${spaceType} ]] # Database only --> Total database usage (DATA+FRA)
        then
                msgPrint -debug "MAIN:$LINENO" "Entering --> Database only"
                if [[ ${loginString} = "/ as sysdba" ]]
                then
                        setOracleEnvironment ${database} > /dev/null 2>&1
                fi
                # Get DB Unique Name
                dbUniqueName=$(getUniqueName ${database} ${loginString})
                # Get db_recovery_file_dest_size
                fraQuota=$(getFraQuota ${database} ${loginString})
                # Get FRA name
                fraName=$(getFraName ${database} ${loginString})
                # Get DATA Name
                dataName=$(getDataName ${database} ${loginString})
                query="SELECT (SELECT round(sum(f.file_size*t.blocksize/1024/1024/1024),2) USED_GB FROM v\$filespace_usage f, sys.ts\$ t WHERE t.ts#=f.tablespace_id)"
                if [[ "${noFraOption}" -eq 1 ]]
                then
                        msgPrint -debug "MAIN:$LINENO" "NO-FRA option"
                        query="${query}+(SELECT round(sum(bytes/1024/1024/1024),2) FROM v\$log) FROM dual"
                else
                        msgPrint -debug "MAIN:$LINENO" "default option"
                        query="${query}+(SELECT round(sum(percent_space_used/100*${fraQuota}),2) FROM v\$recovery_area_usage) FROM dual"
                fi
        elif [[ -z ${database} && -n ${diskGroup} && -z ${spaceType} ]] # Disk Group only --> Total space for Disk Group
        then
                msgPrint -debug "MAIN:$LINENO" "Entering --> Diskgroup only"
                case ${diskGroup} in
                        ("${dataName}"|"${fraName}")
                                msgPrint -debug "MAIN:$LINENO" "Correct diskgroup"
                                query="SELECT round(a.total_mb/1024/factor,2) TOTAL_GB FROM v\$asm_diskgroup a, (select name, decode(type,'EXTERN', 1, 'NORMAL', 2, 'HIGH', 3) factor from v\$asm_diskgroup) d  WHERE a.name='${diskGroup}' AND a.name=d.name"
                        ;;
                        ("FS")
                                msgPrint -debug "MAIN:$LINENO" "Filesystem"
                                query="SELECT 'NOT IMPLEMENTED YET' FROM dual"
                        ;;
                esac
        elif [[ -z ${database} && -z ${diskGroup} && -n ${spaceType} ]] # Space Type only --> Space type for cluster storage (based on current database)
        then
                msgPrint -debug "MAIN:$LINENO" "Entering --> Space type only"
                if [[ -z ${ORACLE_HOME} || -z ${ORACLE_BASE} ]]
                then
                        msgPrint -debug "MAIN:$LINENO" "Impossible run"
                        echo -1
                        return 1
                else
                        # Get DB Unique Name
                        dbUniqueName=$(getUniqueName ${database} ${loginString})
                        # Get db_recovery_file_dest_size
                        fraQuota=$(getFraQuota $dbUniqueName ${loginString})
                        # Get FRA name
                        fraName=$(getFraName $dbUniqueName ${loginString})
                        # Get DATA Name
                        dataName=$(getDataName $dbUniqueName ${loginString})
                        case ${spaceType} in
                                ("USED")
                                        msgPrint -debug "MAIN:$LINENO" "Calculating USED space"
                                        query="SELECT round(sum(g.hot_used_mb/1024),2)+round(sum(g.cold_used_mb/1024),2) USED_GB FROM v\$asm_diskgroup g  WHERE g.name IN ('${dataName}','${fraName}')"
                                ;;
                                ("ALLOCATED")
                                        msgPrint -debug "MAIN:$LINENO" "Calculating ALLOCATED space"
                                        query="SELECT round(sum(f.space/1024/1024/1024),2) ALLOC_GB FROM v\$asm_file f ,v\$asm_diskgroup g WHERE f.group_number=g.group_number AND g.name IN ('${dataName}','${fraName}')"
                                ;;
                                ("MAX")
                                        msgPrint -debug "MAIN:$LINENO" "Calculating MAX space"
                                        query="SELECT ROUND(SUM(f.maxbytes/1024/1024/1024),2) MAX_SIZE_GB FROM dba_data_files f"
                                ;;
                                ("FREE")
                                        msgPrint -debug "MAIN:$LINENO" "Calculating FREE space"
                                        query="SELECT ROUND(sum(free_mb/1024),2) USED_GB FROM v\$asm_diskgroup g  WHERE g.name IN ('${dataName}','${fraName}')"
                                ;;
                                ("TOTAL")
                                        msgPrint -debug "MAIN:$LINENO" "Calculating total space"
                                        query="SELECT round(sum(g.hot_used_mb/1024)+sum(g.cold_used_mb/1024)+sum(free_mb/1024),2) USED_GB FROM v\$asm_diskgroup g  WHERE g.name IN ('${dataName}','${fraName}')"
                                ;;
                        esac
                fi
        elif [[ -n ${database} && -n ${diskGroup} && -z ${spaceType} ]] # Database and Disk Group --> Total size in ASM Disk Group for the database
        then
                msgPrint -debug "MAIN:$LINENO" "Entering --> Database + Diskgroup"
                if [[ ${loginString} = "/ as sysdba" ]]
                then
                        setOracleEnvironment ${database} > /dev/null 2>&1
                fi
                query="SELECT /*+RULE*/ ROUND(SUM(file_size)/1024/1024/1024,2) USED_GB FROM (SELECT b.name gname, a.parent_index pindex, a.name aname, a.reference_index rindex , a.system_created, a.alias_directory, c.type file_type, c.bytes file_size FROM v\$asm_alias a, v\$asm_diskgroup b, v\$asm_file c, (select name, decode(type,'EXTERN', 1, 'NORMAL', 2, 'HIGH', 3) factor from v\$asm_diskgroup) d WHERE a.group_number = b.group_number AND b.name=d.name AND a.group_number = c.group_number (+) AND a.file_number = c.file_number (+) AND a.file_incarnation = c.incarnation (+)) WHERE file_type IN ('ARCHIVELOG','ASMPARAMETERFILE','ASMVOL','BACKUPSET','CHANGETRACKING','CONTROLFILE','DATAFILE','FLASHBACK','OCRBACKUP','OCRFILE','ONLINELOG','PARAMETERFILE','PASSWORD','TEMPFILE') START WITH (mod(pindex, power(2, 24))) = 0 AND rindex IN    (SELECT a.reference_index FROM v\$asm_alias a, v\$asm_diskgroup b WHERE a.group_number = b.group_number AND (mod(a.parent_index, power(2, 24))) = 0 AND a.name = upper('${dbUniqueName}') AND b.name = upper('${diskGroup}')) CONNECT BY prior rindex = pindex"
        elif [[ -n ${database} && -z ${diskGroup} && -n ${spaceType} ]] # Database and Space Type --> Space type total for the database
        then
                msgPrint -debug "MAIN:$LINENO" "Entering Database + Space type"
                if [[ ${loginString} = "/ as sysdba" ]]
                then
                        setOracleEnvironment ${database} > /dev/null 2>&1
                fi
                # Get DB Unique Name
                dbUniqueName=$(getUniqueName ${database} ${loginString})
                # Get db_recovery_file_dest_size
                fraQuota=$(getFraQuota ${database} ${loginString})
                # Get FRA name
                fraName=$(getFraName ${database} ${loginString})
                # Get DATA Name
                dataName=$(getDataName ${database} ${loginString})
                case ${spaceType} in
                "USED")
                        msgPrint -debug "MAIN:$LINENO" "Calculating USED"
                        query="SELECT /*+RULE*/ ROUND(SUM(file_size)/1024/1024/1024,2) USED_GB FROM (SELECT b.name gname, a.parent_index pindex, a.name aname, a.reference_index rindex , a.system_created, a.alias_directory, c.type file_type, c.bytes file_size FROM v\$asm_alias a, v\$asm_diskgroup b, v\$asm_file c WHERE a.group_number = b.group_number AND a.group_number = c.group_number (+) AND a.file_number = c.file_number (+) AND a.file_incarnation = c.incarnation (+)) WHERE file_type IN ('ARCHIVELOG','ASMPARAMETERFILE','ASMVOL','BACKUPSET','CHANGETRACKING','CONTROLFILE','DATAFILE','FLASHBACK','OCRBACKUP','OCRFILE','ONLINELOG','PARAMETERFILE','PASSWORD','TEMPFILE') START WITH (mod(pindex, power(2, 24))) = 0 AND rindex IN (SELECT a.reference_index FROM v\$asm_alias a, v\$asm_diskgroup b WHERE a.group_number = b.group_number AND (mod(a.parent_index, power(2, 24))) = 0 AND a.name = upper('${dbUniqueName}') AND b.name IN ('${dataName}','${fraName}')) CONNECT BY prior rindex = pindex"
                ;;
                "ALLOCATED")
                        msgPrint -debug "MAIN:$LINENO" "Calculating ALLOCATED"
                        query="SELECT /*+RULE*/ ROUND(SUM(space)/1024/1024/1024,2) USED_GB FROM (SELECT b.name gname, a.parent_index pindex, a.name aname, a.reference_index rindex , a.system_created, a.alias_directory, c.type file_type, c.space space FROM v\$asm_alias a, v\$asm_diskgroup b, v\$asm_file c WHERE a.group_number = b.group_number AND a.group_number = c.group_number (+) AND a.file_number = c.file_number (+) AND a.file_incarnation = c.incarnation (+)) WHERE file_type IN ('ARCHIVELOG','ASMPARAMETERFILE','ASMVOL','BACKUPSET','CHANGETRACKING','CONTROLFILE','DATAFILE','FLASHBACK','OCRBACKUP','OCRFILE','ONLINELOG','PARAMETERFILE','PASSWORD','TEMPFILE') START WITH (mod(pindex, power(2, 24))) = 0 AND rindex IN (SELECT a.reference_index FROM v\$asm_alias a, v\$asm_diskgroup b WHERE a.group_number = b.group_number AND (mod(a.parent_index, power(2, 24))) = 0 AND a.name = upper('${dbUniqueName}') AND b.name IN ('${dataName}','${fraName}')) CONNECT BY prior rindex = pindex"
                ;;
                ("MAX")
                        msgPrint -debug "MAIN:$LINENO" "Calculating MAX space"
                        query="SELECT ROUND(SUM(f.maxbytes/1024/1024/1024),2) MAX_SIZE_GB FROM dba_data_files f"
                ;;
                ("FREE")
                        msgPrint -debug "MAIN:$LINENO" "Calculating FREE space"
                        query="SELECT ROUND(sum(g.free_mb/1024/factor),2) TOTAL_GB FROM v\$asm_diskgroup g, (select name, decode(type,'EXTERN', 1, 'NORMAL', 2, 'HIGH', 3) factor from v\$asm_diskgroup) f WHERE g.name=f.name AND g.name IN ('${dataName}','${fraName}')"
                ;;
                "TOTAL")
                        msgPrint -debug "MAIN:$LINENO" "Calculating TOTAL"
                        if [[ $(isCluster ${database} ${loginString}) = "TRUE" ]]
                        then
                                msgPrint -debug "MAIN:$LINENO" "Calculating for CLUSTER"
                                query="SELECT round(sum(g.hot_used_mb/1024/factor) + sum(g.cold_used_mb/1024/factor) + sum(g.free_mb/1024/factor),2) TOTAL_GB FROM v\$asm_diskgroup g, (select name, decode(type,'EXTERN', 1, 'NORMAL', 2, 'HIGH', 3) factor from v\$asm_diskgroup) f WHERE g.name=f.name AND g.name IN ('${dataName}','${fraName}')"
                        else
                                query="SELECT 'NOT IMPLEMENTED YET' FROM DUAL"
                        fi
                ;;
                *)
                        echo -1
                        return 1
                ;;
                esac
        elif [[ -z ${database} && -n ${diskGroup} && -n ${spaceType} ]] # Disk Group and Space Type --> Total space type for diskgroup
        then
                msgPrint -debug "MAIN:$LINENO" "Entering --> Diskgroup + Space Type"
                if [[ -z ${ORACLE_HOME} || -z ${ORACLE_BASE} ]]
                then
                        msgPrint -debug "MAIN:$LINENO" "No database: Impossible run"
                        echo -1
                        return 1
                else
                        case ${spaceType} in
                        "USED")
                                msgPrint -debug "MAIN:$LINENO" "Calculating USED"
                                case ${diskGroup} in
                                "${dataName}")
                                        query="SELECT round(sum(f.bytes/1024/1024/1024),2) USED_GB FROM v\$asm_file f, v\$asm_diskgroup g WHERE g.name='${diskGroup}' and f.group_number=g.group_number"
                                ;;
                                "${fraName}")
                                        query="SELECT round(sum((total_mb/1024)*(u.percent_space_used/100)),2) USED_GB FROM v\$flash_recovery_area_usage u, v\$asm_diskgroup d WHERE name='${diskGroup}'"
                                ;;
                                "FS")
                                        msgPrint -warning "-- FS NOT IMPLEMENTED YET $LINENO --"
                                ;;
                                *)
                                        query="SELECT 'WRONG DISK GROUP NAME' FROM dual"
                                ;;
                                esac
                        ;;
                        "ALLOCATED")
                                msgPrint -debug "MAIN:$LINENO" "Calculating ALLOCATED"
                                case ${diskGroup} in
                                "${dataName}")
                                        query="SELECT /*+RULE*/round(sum(f.space/1024/1024/1024),2) USED_GB FROM v\$asm_file f, v\$asm_diskgroup g, (select name, decode(type,'EXTERN', 1, 'NORMAL', 2, 'HIGH', 3) factor from v\$asm_diskgroup) a WHERE g.name='${diskGroup}' and f.group_number=g.group_number AND g.name=a.name"
                                ;;
                                "${fraName}")
                                        query="SELECT /*+RULE*/round(sum((total_mb/1024)*(u.percent_space_used/100)),2) USED_GB FROM v\$flash_recovery_area_usage u, v\$asm_diskgroup d WHERE name='${diskGroup}'"
                                ;;
                                "FS")
                                        msgPrint -warning "-- FS NOT IMPLEMENTED YET $LINENO --"
                                ;;
                                *)
                                        query="SELECT 'WRONG DISK GROUP NAME' FROM dual"
                                ;;
                                esac
                        ;;
                        ("MAX")
                                msgPrint -debug "MAIN:$LINENO" "Calculating MAX space"
                                case ${diskGroup} in
                                "${dataName}")
                                        query="SELECT ROUND(SUM(f.maxbytes/1024/1024/1024),2) MAX_SIZE_GB FROM dba_data_files f"
                                ;;
                                "${fraName}")
                                        query="SELECT ${fraQuota} FROM dual"
                                ;;
                                *)
                                        query="SELECT 'WRONG DISK GROUP NAME' FROM dual"
                                ;;
                                esac
                        ;;
                        ("FREE")
                                msgPrint -debug "MAIN:$LINENO" "Calculating FREE space"
                                query="SELECT ROUND(sum(g.free_mb/1024/factor),2) TOTAL_GB FROM v\$asm_diskgroup g, (select name, decode(type,'EXTERN', 1, 'NORMAL', 2, 'HIGH', 3) factor from v\$asm_diskgroup) f WHERE g.name=f.name AND g.name IN ('${diskGroup}')"
                        ;;
                        "TOTAL")
                                msgPrint -debug "MAIN:$LINENO" "Calculating TOTAL"
                                if [[ $(isCluster ${database} ${loginString}) = "TRUE" ]]
                                then
                                        msgPrint -debug "MAIN:$LINENO" "for CLUSTER"
                                        query="SELECT round(sum(g.hot_used_mb/1024/factor) + sum(g.cold_used_mb/1024/factor) + sum(g.free_mb/1024/factor),2) TOTAL_GB FROM v\$asm_diskgroup g, (select name, decode(type,'EXTERN', 1, 'NORMAL', 2, 'HIGH', 3) factor from v\$asm_diskgroup) f WHERE g.name=f.name AND g.name IN ('${dataName}','${fraName}')"
                                else
                                        query=""
                                        msgPrint -warning "-- NOT A CLUSTER. NOT IMPLEMENTED YET 1 --"
                                fi
                        ;;
                        *)
                                msgPrint -error "Unrecognized input, please correct the type and try again"
                        ;;
                        esac
                fi
        elif [[ -n ${database} && -n ${diskGroup} && -n ${spaceType} ]] # All arguments provided -->Space Type total for a database in a disk group
        then
                msgPrint -debug "MAIN:$LINENO" "Entering --> All arguments"
                if [[ ${loginString} = "/ as sysdba" ]]
                then
                        setOracleEnvironment ${database} > /dev/null 2>&1
                fi
                # Get DB Unique Name
                dbUniqueName=$(getUniqueName ${database} ${loginString})
                # Get db_recovery_file_dest_size
                fraQuota=$(getFraQuota ${database} ${loginString})
                # Get FRA name
                fraName=$(getFraName ${database} ${loginString})
                # Get DATA Name
                dataName=$(getDataName ${database} ${loginString})
                case ${spaceType} in
                "USED")
                        msgPrint -debug "MAIN:$LINENO" "Calculating USED"
                        case ${diskGroup} in
                        "${dataName}")
                                query="SELECT /*+RULE*/ ROUND(SUM(file_size)/1024/1024/1024,2) USED_GB FROM (SELECT b.name gname, a.parent_index pindex, a.name aname, a.reference_index rindex , a.system_created, a.alias_directory, c.type file_type, c.bytes file_size FROM v\$asm_alias a, v\$asm_diskgroup b, v\$asm_file c WHERE a.group_number = b.group_number AND a.group_number = c.group_number (+) AND a.file_number = c.file_number (+) AND a.file_incarnation = c.incarnation (+)) WHERE file_type = '${fileType}' START WITH (mod(pindex, power(2, 24))) = 0 AND rindex IN (SELECT a.reference_index FROM v\$asm_alias a, v\$asm_diskgroup b WHERE a.group_number = b.group_number AND (mod(a.parent_index, power(2, 24))) = 0 AND a.name = upper('${dbUniqueName}') AND b.name = '${diskGroup}') CONNECT BY prior rindex = pindex"
                        ;;
                        "${fraName}")
                                query="SELECT /*+RULE*/ ROUND(SUM(file_size)/1024/1024/1024,2) USED_GB FROM (SELECT b.name gname, a.parent_index pindex, a.name aname, a.reference_index rindex , a.system_created, a.alias_directory, c.type file_type, c.bytes file_size FROM v\$asm_alias a, v\$asm_diskgroup b, v\$asm_file c WHERE a.group_number = b.group_number AND a.group_number = c.group_number (+) AND a.file_number = c.file_number (+) AND a.file_incarnation = c.incarnation (+)) WHERE file_type = '${fileType}' START WITH (mod(pindex, power(2, 24))) = 0 AND rindex IN (SELECT a.reference_index FROM v\$asm_alias a, v\$asm_diskgroup b WHERE a.group_number = b.group_number AND (mod(a.parent_index, power(2, 24))) = 0 AND a.name = upper('${dbUniqueName}') AND b.name = '${diskGroup}') CONNECT BY prior rindex = pindex"
                                # query="SELECT round(sum((total_mb/1024)*(u.percent_space_used/100)),2) USED_GB FROM v\$flash_recovery_area_usage u, v\$asm_diskgroup d WHERE name='${diskGroup}'"
                        ;;
                        "FS")
                                query="SELECT round(sum(f.file_size/1024/1024),2) USED_GB FROM v\$filespace_usage f"
                        ;;
                        *)
                                query="SELECT round(sum(f.file_size/1024/1024),2) USED_GB FROM v\$filespace_usage f"
                        ;;
                        esac
                ;;
                "ALLOCATED")
                        msgPrint -debug "MAIN:$LINENO" "Calculating ALLOCATED"
                        case ${diskGroup} in
                        "${dataName}")
                                query="SELECT /*+RULE*/ ROUND(SUM(space)/1024/1024/1024,2) USED_GB FROM (SELECT b.name gname, a.parent_index pindex, a.name aname, a.reference_index rindex , a.system_created, a.alias_directory, c.type file_type, c.space space FROM v\$asm_alias a, v\$asm_diskgroup b, v\$asm_file c WHERE a.group_number = b.group_number AND a.group_number = c.group_number (+) AND a.file_number = c.file_number (+) AND a.file_incarnation = c.incarnation (+)) WHERE file_type IN ('ARCHIVELOG','ASMPARAMETERFILE','ASMVOL','BACKUPSET','CHANGETRACKING','CONTROLFILE','DATAFILE','FLASHBACK','OCRBACKUP','OCRFILE','ONLINELOG','PARAMETERFILE','PASSWORD','TEMPFILE') START WITH (mod(pindex, power(2, 24))) = 0 AND rindex IN (SELECT a.reference_index FROM v\$asm_alias a, v\$asm_diskgroup b WHERE a.group_number = b.group_number AND (mod(a.parent_index, power(2, 24))) = 0 AND a.name = upper('${dbUniqueName}') AND b.name = '${dataName}') CONNECT BY prior rindex = pindex"
                        ;;
                        "${fraName}")
                                query="SELECT '${fraQuota}' from dual"
                        ;;
                        "FS")
                                msgPrint -warning "-- FS NOT IMPLEMENTED YET $LINENO --"
                        ;;
                        esac
                ;;
                ("MAX")
                        msgPrint -debug "MAIN:$LINENO" "Calculating MAX space"
                        case ${diskGroup} in
                        "${dataName}")
                                query="SELECT ROUND(SUM(f.maxbytes/1024/1024/1024),2) MAX_SIZE_GB FROM dba_data_files f"
                        ;;
                        "${fraName}")
                                query="SELECT ${fraQuota} FROM dual"
                        ;;
                        *)
                                query="SELECT 'WRONG DISK GROUP NAME' FROM dual"
                        ;;
                        esac
                ;;
                ("FREE")
                        msgPrint -debug "MAIN:$LINENO" "Calculating FREE space"
                        query="SELECT ROUND(sum(g.free_mb/1024/factor),2) TOTAL_GB FROM v\$asm_diskgroup g, (select name, decode(type,'EXTERN', 1, 'NORMAL', 2, 'HIGH', 3) factor from v\$asm_diskgroup) f WHERE g.name=f.name AND g.name = '${diskGroup}'"
                ;;
                "TOTAL")
                        msgPrint -debug "MAIN:$LINENO" "Calculating cluster"
                        msgPrint -debug "isCluster: isCluster ${database} ${loginString}"
                        if [[ $(isCluster ${database} ${loginString}) = "TRUE" ]]
                        then
                                query="SELECT round(sum(g.hot_used_mb/1024/factor) + sum(g.cold_used_mb/1024/factor) + sum(g.free_mb/1024/factor),2) TOTAL_GB FROM v\$asm_diskgroup_stat g, (select name, decode(type,'EXTERN', 1, 'NORMAL', 2, 'HIGH', 3) factor from v\$asm_diskgroup_stat) f WHERE g.name=f.name AND g.name = '${diskGroup}'"
                        else
                                query="SELECT -1 FROM dual"
                        fi
                ;;
                *)
                        msgPrint -error "Unrecognized input, please correct the type and try again"
                ;;
                esac
        fi
if [[ -z "${diskGroup}" ]]
then
        spoolFile=${TEMPDIR}/spool_$$.tmp
                (sqlplus ${loginString}<<_EOSQL_
        set pagesize 0
        set heading off
        set feedback off
        set echo off
        spool $spoolFile
        ${query};
        spool off
        exit
_EOSQL_
        ) > /dev/null 2>&1
        if [[ ${DEBUG} -eq 1 ]]
        then
                msgPrint -none "Spool File"
                msgPrint -separator
                cat ${spoolFile}
                msgPrint -separator
        fi
        result=$(cat ${spoolFile} | grep -vi SELECT | grep -vi FROM | grep -vi WHERE | grep -vi spool | grep -v ">" | tr -d [:space:])
        rm -f ${spoolFile}
        if [[ -z ${result} ]]
        then
                echo "0"
        else
                echo ${result}
        fi
elif [[ -n "${diskGroup}" && "${diskGroup}" = "${dataName}" || "${diskGroup}" = "${fraName}" ]]
then
        spoolFile=${TEMPDIR}/spool_$$.tmp
                (sqlplus ${loginString}<<_EOSQL_
        set pagesize 0
        set heading off
        set feedback off
        set echo off
        spool $spoolFile
        ${query};
        spool off
        exit
_EOSQL_
        ) > /dev/null 2>&1
        if [[ ${DEBUG} -eq 1 ]]
        then
                msgPrint -none "Spool File"
                msgPrint -separator
                cat ${spoolFile}
                msgPrint -separator
        fi
        result=$(cat ${spoolFile} | grep -vi SELECT | grep -vi FROM | grep -vi WHERE | grep -vi spool | grep -v ">" | tr -d [:space:])
        rm -f ${spoolFile}
        if [[ -z ${result} ]]
        then
                echo "0"
        else
                echo ${result}
        fi
else
        echo -1
fi
unset database
DEBUG=0
return 0
}


##################################
##
##	Function: isCluster
##
##	Description:
##		This function sets the Oracle Environment
##	based on entries of the /etc/oratab file and sources
##	the include file of the DAN
##
##	Usage: <variable>=$(isCluster <DATABASE> <LOGIN_STRING>)
##
#############################################
function isCluster {
	database=$1
	loginString=$2
	if [[ -z $database && -z $ORACLE_SID ]]
	then
		echo "No Database Defined"
	else
		spoolFile=$TEMPDIR/isCluster_$$.tmp
		if [[ -z ${loginString} ]]
		then
			loginString="/ as sysdba"
			setOracleEnvironment $database
		fi
	(sqlplus ${loginString} <<_EOSQL_
	set pagesize 0
	set heading off
	set feedback off
	set echo off
	spool $spoolFile
	SELECT value FROM v\$spparameter where UPPER(name)='CLUSTER_DATABASE';
	spool off
	exit
_EOSQL_
) > /dev/null 2>&1
		maxInst=$(cat ${spoolFile} |grep -i "TRUE" | tr -d [:space:])
		if [[ -n $maxInst ]]
		then
			echo "TRUE"
		else
			echo "FALSE"
		fi
		rm $spoolFile
	fi
}

#################################
##
##	Function: validateCreds
##
##	Description:
##		This function returns TRUE if credentials are good for the database
##	or FALSE if they're not
##
##	Pre-requisites: Oracle environment must have been set
##
##	Usage: <VARIABLE>=validateCreds <DATABASE> <LOGIN STRING>
##
#####################################################
function validateCreds {
	database=$1
	loginString=$2
	if [[ -z $database && -z $ORACLE_SID ]]
	then
		echo "No Database Defined"
	else
		spoolFile=$TEMPDIR/validCreds_$$.tmp
		if [[ -z ${loginString} ]]
		then
			loginString="/ as sysdba"
			setOracleEnvironment $database
		fi
		(sqlplus ${loginString}<<_EOSQL_
set pagesize 0
set heading off
set feedback off
set echo off
--spool $spoolFile
select 'USER '||USER||' LOGGED IN' from dual;
--spool off;
exit
_EOSQL_
) > ${spoolFile}
		valid=$(cat ${spoolFile} | grep 'USER' | grep 'LOGGED' | grep 'IN' | tr -d [:space:])
		if [[ -z ${valid} ]]
		then
			echo "FALSE"
		else
			echo "TRUE"
		fi
	fi
	rm -f ${spoolFile}
}

##########################
#
#	Function: schemaExists
#
#	Description:
#		This function checks that the schema exists in the database
#	to avoid PLS or ORA errors due to wrong schema names passed
#	as arguments to this script.
#
#	Usage: schemaExists <SCHEMA> <DATABASE> <LOGIN STRING>
#
##############################################
function schemaExists {
	schema=$1
	database=$2
	loginString=$3
	if [[ -z $database && -z $ORACLE_SID ]]
	then
		echo "No Database Defined"
	else
		spoolFile=$TEMPDIR/_${schema}_check_$$.tmp
		if [[ -z ${loginString} ]]
		then
			loginString="/ as sysdba"
			setOracleEnvironment $database
		fi
		(sqlplus ${loginString}<<_EOSQL_
set pagesize 0
set heading off
set feedback off
set echo off
--spool $spoolFile
select username from dba_users where username = '${schema}';
--spool off;
exit
_EOSQL_
) > ${spoolFile}
		exists=$(cat $TEMPDIR/$1_$2_CHECK.txt | grep -v ">" | grep ${schema} | tr -d [:space:])
		if [[ -z ${exists} ]]
		then
			return 1
		else
			return 0
		fi
		rm -f ${spoolFile}
	fi
}

##################################
##
##	Function: setOracleEnvironment
##
##	Description:
##		This function sets the Oracle Environment
##	based on entries of the /etc/oratab file and sources
##	the include file of the DAN
##
##	Usage: . setOracleEnvironment <DATABASE>
##
#############################################
function setOracleEnvironment {
	databaseName=${1}
	msgPrint -debug "oracle_utilities.sh:setOracleEnvironment:$LINENO" "Checking Oracle Environment"
	msgPrint -debug "oracle_utilities.sh:setOracleEnvironment:$LINENO" "Looking for cluster instance name"
	export instanceName=""
	instanceName=$(cat /etc/oratab | grep ${databaseName} | grep -v -w ${databaseName} |cut -d":" -f1)
	if [[ -z $instanceName ]]
	then
		if [[ $CLUSTER -eq 1 ]]
		then
			msgPrint -debug "oracle_utilities.sh:setOracleEnvironment:$LINENO" "Single Instance detected"
			CLUSTER=0
		else
			msgPrint -debug "oracle_utilities.sh:setOracleEnvironment:$LINENO" "Single Instance confirmed"
		fi
		instanceName=$databaseName
	else
		if [[ $CLUSTER -eq 1 ]]
		then
			msgPrint -debug "oracle_utilities.sh:setOracleEnvironment:$LINENO" "Cluster confirmed"
		else
			msgPrint -debug "oracle_utilities.sh:setOracleEnvironment:$LINENO" "Cluster detected"
			CLUSTER=1
		fi
	fi
	addToPath=$(cat /etc/oratab | grep -w ${instanceName} |cut -d":" -f2)
	export PATH=$addToPath/bin:/usr/local/bin:$PATH
	if [[ -z $ORACLE_SID || -z $ORACLE_HOME || $ORACLE_SID != $instanceName ]]
	then
		if [[ -z $instanceName ]]
		then
			#msgPrint -critical "Oracle environment not set, please set it or use the correct arguments"
			printUsage
			return 1
		else
			msgPrint -debug "Database argument found"
			#msgPrint -debug "Setting oracle environment variables"
			export ORACLE_SID=$instanceName
			export ORAENV_ASK=NO
			source oraenv $instanceName
		fi
	fi
	# Final Oracle Environment check
	if [[ -z $ORACLE_HOME || $ORACLE_SID != $instanceName ]]
	then
		msgPrint -critical "Oracle environment not set or ORACLE_SID does not match required instance, please set it manually or use the correct arguments"
		printUsage
		return 1
	fi
	export LD_LIBRARY_PATH=$LD_LIBRARY_PATH:$ORACLE_HOME/lib
	# If there's an include file, source it
	includeFile="/opt/oracle/local/bin/${instanceName}.dba_include.sh"
	if [ -f $includeFile ]
	then 
		#msgPrint -info "Sourcing $includeFile"
		source $includeFile
	fi
	msgPrint -debug "Oracle Environment check/setup complete"
	#msgPrint -separator
	#msgPrint -blank
	export ORAENV_ASK=YES
}

