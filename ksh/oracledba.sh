#!/usr/bin/ksh

###########################
##
##	File: oracledba.sh
##
##	Author: Jesus Sanchez (jsanchez.consultant@gmail.com)
##
##	Copyright Notice: Creative Commons Attribution-ShareAlike 4.0 International License
##
###############################################

#############################
# Utility Functions Preload #
#############################

export LAUNCH_DIR=$(pwd)
export SOURCE_DIR=$( cd -P -- "$(dirname -- "$(command -v -- "$0")")" && pwd -P )
echo $SOURCE_DIR
source $SOURCE_DIR/utility_functions.ksh
if [[ -d $SOURCE_DIR/tmp ]]
then
	mkdir -p $SOURCE_DIR/tmp
fi
export TEMPDIR=$SOURCE_DIR/tmp




if [ -n $(echo "${SHELL}" | grep "ksh") ]
then
	# Set prompt
	export PS1=$'\e[32;1m[\e[36;1m`whoami`\e[0m@`hostname`: \e[31;1m\${ORACLE_SID}\e[32;1m] \e[0m\${PWD##*/} \\$ '
elif [ -n $(echo "${SHELL}" | grep "bash") ]
then
	# Set prompt
	export PS1=$'\\u@\h [${ORACLE_SID}] \\W \\$> '
fi

# Aliases
alias setora='setOracleEnvironment $*'
alias soe='setOracleEnvironment $*'
alias pspmon='ps -ef|grep -v grep |grep pmon| tr -s [:space:] | cut -d" " -f8 | cut -d"_" -f3 | sort'
alias sysdba='sqlplus / as sysdba'
alias oratab='cat /etc/oratab | grep :/ | grep -v agent |cut -d':' -s -f1'
alias cattns='cat $ORACLE_HOME/network/admin/tnsnames.ora'
alias tnsfile='$ORACLE_HOME/network/admin/tnsnames.ora'
