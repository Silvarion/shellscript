#!/bin/bash

###################
##
##  Filename: mysql_crawler.sh
##
##  Description:
##      This script is intended to run some command or script in any number of
##  MySQL databases
##
##  Usage: ./mysql_crawler.sh -v -u <username> -p -d host1,host2,host3,...,hostN -c "SELECT 'I am connected';"
##
##  Usage: ./mysql_crawler.sh -v -u <username> -p -d host1,host2,host3,...,hostN -s /path/to/sql/script
##
#############################

## Title ##
printf "\n\nWELCOME TO THE MYSQL GRANTS COMPARATOR\n========================================\n"

## Argument parsing ##
printf "\n[INFO] Processing arguments...\n"
while getopts ":vc:d:psu:" option
do
    case ${option} in
        v)  printf "[INFO] Verbose mode ON\n"
            verbose="true"
        ;;
        b)  printf "[INFO] Output with table format"
            asFormat="-b "
        ;;
        c)  printf "[INFO] Command provided via argument\n"
            command="${OPTARG}"
        ;;
        d)  printf "[INFO] Database list provided via argument\n"
            dbHostRawList=${OPTARG}
            if [[ $verbose = "true" ]]
            then
                printf "[VERBOSE] DB Raw List: \n${dbHostRawList}\n"
            fi
        ;;
        p)  printf "[INFO] Password will be requested before connecting to the databases\n"
            askForPassword=1
        ;;
        t)  printf "[INFO] Output with table format"
            asFormat="-t "
        ;;
        s)  printf "[INFO] Script provided via argument\n"
            if [[ -r ${OPTARG} ]]
            then
                script=${OPTARG}
            else
                printf "[ERROR] Can't find the provided script, please check the path and try again"
            fi
        ;;
        u)  printf "[INFO] Username provided via argument\n"
            dbUser=${OPTARG}
        ;;
        \?)  printf "[WARNING] Unrecognized argument ${OPTARG}\n"
        ;;
        :)  printf "[ERROR] Option ${OPTARG} requires a value or a comma-separated list of values\n"
        ;;
    esac
done

printf "\n[INFO] Checking requirements...\n"
if [[ -z $MYSQL_PWD ]]
then
    if [[ ${askForPassword} -eq 1 ]]
    then
        printf "[INPUT] Please enter the database password for account ${dbUser}: "
        stty_orig=$(stty -g)
        stty -echo
        read dbPswd
        stty $stty_orig
        printf "\n\n"
        export MYSQL_PWD="${dbPswd}"
    fi
fi

dbHostList=$(echo ${dbHostRawList} | tr "," " " | tr -s [:space:] | tr " " "\n")

if [[ $verbose = "true" ]]
then
    printf "[VERBOSE] DB List: \n${dbHostList}\n"
fi

## Gathering users in the databases
printf "\n[INFO] Starting db crawl...\n"
for dbHost in ${dbHostList}
do
    printf "[INFO] Connecting to ${dbHost}\n"
    if [[ -n "${command}" ]]
    then
        mysql ${asFormat}-u"${dbUser}" -h ${dbHost} -e "${command}"
    elif [[ -n "${script}" ]]
    then
        mysql ${asFormat}-u"${dbUser}" -h ${dbHost} < ${script}
    fi
done
