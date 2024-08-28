#!/bin/bash
##
## Copyright (c) 2011 Ericsson AB, 2010 - 2011.
##
## All Rights Reserved. Reproduction in whole or in part is prohibited
## without the written consent of the copyright owner.
##
## ERICSSON MAKES NO REPRESENTATIONS OR WARRANTIES ABOUT THE
## SUITABILITY OF THE SOFTWARE, EITHER EXPRESS OR IMPLIED, INCLUDING
## BUT NOT LIMITED TO THE IMPLIED WARRANTIES OF MERCHANTABILITY,
## FITNESS FOR A PARTICULAR PURPOSE, OR NON-INFRINGEMENT. ERICSSON
## SHALL NOT BE LIABLE FOR ANY DAMAGES SUFFERED BY LICENSEE AS A
## RESULT OF USING, MODIFYING OR DISTRIBUTING THIS SOFTWARE OR ITS
## DERIVATIVES.
##
##  This script is executed when a backup operation is performed on the node.

##
## UTILITIES
##
ECHO="echo -e"
MKDIR=/bin/mkdir
RM=/bin/rm
GREP=/bin/grep
HAGRP=/opt/VRTSvcs/bin/hagrp
SED=/bin/sed
AWK=/bin/awk
AMF_FIND=/usr/bin/amf-find
AMF_ADM=/usr/bin/amf-adm
AMF_STATE=/usr/bin/amf-state
IMMADM=/usr/bin/immadm
TAR=/bin/tar
MV=/bin/mv
CAT=/bin/cat

#############
# BACKUP ENV
#############
SSO_DIR="/ericsson/tor/no_rollback/sso"
OLDPWD=$( pwd )
SCRIPT_NAME=`basename ${0}`
SSO_HOME="${SSO_DIR}/config"
SSO_BACKUP_DIR="${SSO_DIR}/backup"
H_NAME=`/bin/hostname`

##############
# BACKUP-FILE
##############
[ "x${2}" != "x" ] && SSO_BACKUP_NAME=${2}
SSO_BACKUP_FPATH="${SSO_BACKUP_DIR}/${SSO_BACKUP_NAME}.tar.gz"

##############
# FEATURE ENV
##############
ACTIVE_INSTANCE_SU_NAME=""
AM_BACKUP_NAME=am_svccfg
AM_DUMPFILE=${AM_BACKUP_NAME}_${SSO_BACKUP_NAME}.ldif
AM_OPENDS_HOME="/opt/ericsson/sso/heimdallr/opends/bin"
AM_CFG_DUMP_CREATE="cd ${SSO_HOME} && su litp_jboss -c '${AM_OPENDS_HOME}/export-ldif -l ${SSO_HOME}/${AM_DUMPFILE} -n userRoot'"
AM_CFG_DUMP_RESTORE="cd ${SSO_HOME} && su litp_jboss -c '${AM_OPENDS_HOME}/import-ldif -l ${SSO_HOME}/${AM_DUMPFILE} -n userRoot'"

#############
# FUNCTIONS #
#############
##
## INFORMATION print
##
info()
{
	logger -s -t TOR_SSO_BACKUP -p user.notice "INFORMATION ($SCRIPT_NAME): $@"
}

error()
{
	logger -s -t TOR_SSO_BACKUP -p user.err "ERROR ($SCRIPT_NAME): $@"
}

##
##
##
print_usage ()
{
	${ECHO} "Invalid command: $0 $*"
	${ECHO} "Usage: $0 { prepare <label> | create <label> | restore <label> | remove <label> | list}"
}
##
## Check the exit value from the last command and return 1 if it failed.
##
check_exit_value ()
{
	if [ $? -ne 0 ]
	then
		error "$1"
		exit 1
	fi
}

##
## Remove a file or a directory
##
remove_file ()
{
	#-- remove backupfile --#
	${RM} -rf "$1" 2>/dev/null
	check_exit_value "Could not remove [ ${1} ]"
}

##
## Create a new tor_sso backup directory
##
create_directory ()
{
	${MKDIR} -p "$1" >/dev/null 2>&1
	check_exit_value "Could not create [ $1 ]"
	info "${1} has been created"
}

##
## Perform immadm action on active JBoss instance on this node
##
## Overrides the "amf-adm" helper command to set a longer timeout value
##
active_instance_action ()
{
	local ADMIN_UNLOCK=1
	local ADMIN_LOCK=2

	info "Attempting ${1} action on ${ACTIVE_INSTANCE_SU_NAME}"

	case ${1} in
		"unlock")
			${IMMADM} -o $ADMIN_UNLOCK $2 -t 300
			;;
		"lock")
			${IMMADM} -o $ADMIN_LOCK $2 -t 300
			;;
		*)
			error "Unsupoorted immadm operation. Exiting"
			exit 1
	esac

	return $?
}

##
## Find JBoss instance on this node
##
find_active_jboss_instance ()
{
	local L_ACTIVE_INSTANCE_NUM=`${HAGRP} -state | ${AWK} -v host="$HOSTNAME" '/SSO/ && $0 ~ host && /ONLINE/ {gsub(/[^0-9]/,"",$1);print $1}'`
	[ "x${L_ACTIVE_INSTANCE_NUM}" = "x" ] && return 1
	ACTIVE_INSTANCE_SU_NAME=`${AMF_FIND} su | ${AWK} -v active="$L_ACTIVE_INSTANCE_NUM" '/SSO/ && $0 ~ active'`
	[ "x${ACTIVE_INSTANCE_SU_NAME}" = "x" ] && return 1
	return 0
}

is_apache_active ()
{
	local L_ACTIVE_HOST=`${HAGRP} -state | ${AWK} '/apache/ && /ONLINE/ {print $3}'`
	[ "${L_ACTIVE_HOST}" = "${HOSTNAME}" ] && return 0 || return 1
}

wait_for_sso ()
{
	info "Waiting for SSO to $1"
	case $1 in
		"lock")
			until ${AMF_STATE} su pres ${ACTIVE_INSTANCE_SU_NAME} | ${GREP} "=UNINSTANTIATED"; do
				sleep 1
			done
			;;
		"unlock")
			until ${AMF_STATE} su pres ${ACTIVE_INSTANCE_SU_NAME} | ${GREP} "=INSTANTIATED"; do
				sleep 1
			done
			;;
		*)
			error "Unsupported action. Exiting"
			exit 1
	esac
}

##
## Prepare tor_sso backup
##
prepare ()
{
	eval ${AM_CFG_DUMP_CREATE}
	check_exit_value "prepare failed [${AM_CFG_DUMP_CREATE}]"
	cd - >> /dev/null
}

##
## Create tor_sso backup
##
create ()
{
	local L_HOME="${SSO_HOME}"

	# OMBS needs prepare/create separated - for everyone else one-step is OK - facilitate OMBS here.
	if [[ -s "${SSO_HOME}/${AM_DUMPFILE}" ]]; then
		info "Backup with label ${SSO_BACKUP_NAME} exists, overwriting"
	fi
	prepare

	# Create the backup directory if it does not exist
	if [[ ! -e ${SSO_BACKUP_DIR} ]]
	then
		create_directory $SSO_BACKUP_DIR
	fi

	cd /
	${TAR} -pczf "$SSO_BACKUP_FPATH.$$.$$" ${L_HOME}/${AM_DUMPFILE}
	check_exit_value "Could not create backup for $SSO_BACKUP_NAME"
	cd - >> /dev/null
	${MV} $SSO_BACKUP_FPATH.$$.$$ $SSO_BACKUP_FPATH
	info "Backup $SSO_BACKUP_FPATH created"
}

##
## remove tor_sso backup
##
remove ()
{
	# Check that the label exist
	if [ -e "${SSO_BACKUP_FPATH}" ]
	then
		remove_file "$SSO_BACKUP_FPATH"
		remove_file "${SSO_HOME}/${AM_DUMPFILE}"
	else
		info "No backup with label $SSO_BACKUP_NAME exists"
		exit 1
	fi
}

##
## restore tor_sso backup
##
restore ()
{
	if is_apache_active; then
		error "SSO config restore being attempted on an active node. Apache should be failed over before attempting this operation again. Exiting"
		exit 1
	fi
	
	# Check that the label exist
	if [ -e "${SSO_BACKUP_FPATH}" ]
	then
		info "${SSO_BACKUP_FPATH} exists"
		if [ -e $SSO_HOME ]
		then
			info "$SSO_HOME"
			remove_file "${SSO_HOME}/repository"
		fi

		local L_HOME=${SSO_HOME}

		create_directory ${L_HOME} >/dev/null 2>&1
		L_HOME=/
		${TAR} -xzf "$SSO_BACKUP_FPATH" -C ${L_HOME}
		check_exit_value "Could not extract backup for label $SSO_BACKUP_NAME"
		
		local L_JBOSS_ACTIVE=0
		find_active_jboss_instance || L_JBOSS_ACTIVE=1

		if [ ${L_JBOSS_ACTIVE} -eq 0 ]; then
			info "Stopping SSO to begin restore procedure"
			active_instance_action lock ${ACTIVE_INSTANCE_SU_NAME}
			wait_for_sso lock
		fi

		eval ${AM_CFG_DUMP_RESTORE}
		check_exit_value "import failed [${AM_CFG_DUMP_RESTORE}]"
		cd - >> /dev/null

		if [ ${L_JBOSS_ACTIVE} -eq 0 ]; then
			info "Restarting SSO to complete restore procedure."
			active_instance_action unlock ${ACTIVE_INSTANCE_SU_NAME}
			wait_for_sso unlock && info "SSO restored to ${SSO_BACKUP_NAME}" || error "Problem with restarting SSO after configuration restore"
		else
			warn "No active SSO instance found on this node. Restore will not be complete until SSO is restarted"
		fi
	else
		error "No backup with label $SSO_BACKUP_NAME exists"
		exit 1
	fi
}

##
## list of tor_sso backup
##
list ()
{
	if [ -d ${SSO_BACKUP_DIR} ]
	then
		FILES="$( ls ${SSO_BACKUP_DIR}/*.tar.gz 2>/dev/null )"
		for x in ${FILES}
		do
			echo $x | sed "s|${SSO_BACKUP_DIR}/||g" | sed "s|.tar.gz||g"
		done
	fi
	remove_file ${AM_KEYFILE}
}

USAGE_ERR=1
case "$1" in
prepare)		if [ "$#" = 2 ]
				then
					USAGE_ERR=0
					prepare
				fi
				;;

create)			if [ "$#" = 2 ]
				then
					USAGE_ERR=0
					create
				fi
				;;

restore)		if [ "$#" = 2 ]
				then
					USAGE_ERR=0
					restore
				fi
				;;

remove)			if [ "$#" = 2 ]
				then
					USAGE_ERR=0
					remove
				fi
				;;

list)			if [ "$#" = 1 ]
				then
					USAGE_ERR=0
					list
				fi
				;;
esac

if (( USAGE_ERR > 0 ))
then
	print_usage
	exit 1
fi
exit 0
