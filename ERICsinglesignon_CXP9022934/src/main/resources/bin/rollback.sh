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
##  This script is executed when an initialisation fails and needs to be rolled back.

# Debug
#set -vx

##############
# Command vars
##############
GREP=/bin/grep
SED=/bin/sed
AWK=/bin/awk
AMF_ADM=/usr/bin/amf-adm
AMF_FIND=/usr/bin/amf-find
HAGRP=/opt/VRTSvcs/bin/hagrp
SCRIPT_NAME=`basename $0`
ECHO="echo -e"
GLOBAL_PROPERTIES=/ericsson/tor/data/global.properties
LOCAL_PROPERTIES=/opt/ericsson/sso/etc/env-vars.conf
##
## INFORMATION print
##
info()
{
	logger -s -t TOR_SSO -p user.notice "INFORMATION ( ${SCRIPT_NAME} ): $@"
}

error()
{
	logger -s -t TOR_SSO -p user.err "ERROR ( ${SCRIPT_NAME} ): $@"
}

##############
# FEATURE ENV
##############

if [ ! -f "${GLOBAL_PROPERTIES}" ]; then
	error "File $GLOBAL_PROPERTIES does not exist. Please create it with appropriate values before running this script again. See /opt/ericsson/sso/etc/global-properties.template for an example"
	exit 1
fi

if [ ! -f "${LOCAL_PROPERTIES}" ]; then
	error "File ${LOCAL_PROPERTIES} does not exist. Script cannot continue. Possible problem with RPM installation. Exiting"
	exit 1
fi
. ${GLOBAL_PROPERTIES}
. ${LOCAL_PROPERTIES}

#############
# FUNCTIONS #
#############
##
## Print simple command usage info
##
print_usage ()
{
	${ECHO} "Invalid command: $0 $*"
	${ECHO} "Usage: $0 {broken-install | force | unsafe}\n"
	${ECHO} "Rollback script to recover from a failed SSO installation.\n"
	${ECHO} "Options:"
	${ECHO} "    broken-install    -    checks for a bad install of SSO, stops the JBoss container that"
	${ECHO} "                           initialised it, and removes the attempted installation."
	${ECHO} "                           On finding a healthy installation, will print a warning and exit 1\n"
	${ECHO} "    force             -    Ignores the check for a good installation and performs rollback\n"
	${ECHO} "    unsafe            -    Deletes the installation directory without checking for an active"
	${ECHO} "                           JBoss instance or attempting to stop it safely. Use only when you"
	${ECHO} "                           are sure there is no SSO JBoss active on this node"
	find_active_jboss_instance
	[ "x${active_instance_su_name}" != "x" ] && print_instance_and_commands || print_no_active_instance
}

print_no_active_instance()
{
	${ECHO} "\nThere is no active JBoss instance on this node. It is safe to remove the SSO installation at ${SSO_FULL_SYMLINK}\n"
}

print_instance_and_commands()
{
	print_active_instance
	print_amf_commands
}

print_active_instance ()
{
	${ECHO} "\nThe JBoss instance that is active on this machine is\n"
	${ECHO} "    ${active_instance_su_name}\n"
}

print_amf_commands ()
{
	${ECHO} "\nTo 'lock' this service unit (Stop the JEE container), run\n"
	${ECHO} "    ${AMF_ADM} lock ${active_instance_su_name}\n"
	${ECHO} "To 'unlock', run\n"
	${ECHO} "    ${AMF_ADM} unlock ${active_instance_su_name}\n"
}

##
## Perform amf-adm action on active JBoss instance on this node
##
active_instance_action ()
{
	info "Attempting ${1} action on ${active_instance_su_name}"
	${AMF_ADM} ${1} ${active_instance_su_name}
}

##
## Find JBoss instance on this node
##
find_active_jboss_instance ()
{
	local active_instance_num=`${HAGRP} -state | ${GREP} SSO | ${GREP} ${HOSTNAME} | ${GREP} ONLINE | ${AWK} '{print $1}' | ${SED} 's/[^0-9]*//g'`
	active_instance_su_name=`${AMF_FIND} su | ${GREP} SSO | ${GREP} ${active_instance_num}`
	[ "x${active_instance_su_name}" = "x" ] && return 1
	return 0
}

print_warning ()
{
	WARNING_MESSAGE="SSO installation at ${SSO_FULL_SYMLINK} is healthy. Run ${SCRIPT_NAME} force to force a rollback."
	WARNING_MESSAGE="${WARNING_MESSAGE} This will stop the JBoss instance, remove the enitre config directory and restart JBoss"
	graceful_exit 1 "${WARNING_MESSAGE}"
}

is_installation_good ()
{
	[ -d ${SSO_FULL_SYMLINK}/opends -a ! -f ${SSO_FULL_SYMLINK}/bootstrap ] && return 1
	[ -f ${SSO_FULL_SYMLINK}/bootstrap ] && return 0
	graceful_exit 1 "No installation of SSO found, cancelling rollback"
}

do_unsafe_rollback ()
{
	info "Forcing delete of configuration from ${SSO_HOME}/${SSO_NAME}. WARNING This may leave the system in an unstable condition"
	delete_installation
	[ "$(ls -A ${SSO_FULL_SYMLINK})" ] && graceful_exit 1 "Unable to clear ${SSO_FULL_SYMLINK}. Possible file ownership/permissions issue" \
	|| info "${SSO_FULL_SYMLINK} cleared"
}

delete_installation ()
{
	info "Deleting configuration from ${SSO_HOME}/${SSO_NAME}"
	rm -rf ${SSO_FULL_SYMLINK}/*
	rm -f ${SSO_FULL_SYMLINK}/.version
}

do_rollback ()
{
	ROLLBACK_FAILURE_MESSAGE="Unable to lock service unit ${active_instance_su_name}. Cancelling rollback."
	ROLLBACK_FAILURE_MESSAGE="${ROLLBACK_FAILURE_MESSAGE} If you are sure there is no SSO JBoss instance running on this machine"
	ROLLBACK_FAILURE_MESSAGE="${ROLLBACK_FAILURE_MESSAGE} you can run ${SCRIPT_NAME} unsafe to forcibly remove the configuration."
	ROLLBACK_FAILURE_MESSAGE="${ROLLBACK_FAILURE_MESSAGE} This will NOT attempt to start the JBoss instance afterwards"
	find_active_jboss_instance && info "Active JBoss found on this node, attempting lock" || error "No active JBoss found on this node"
	active_instance_action lock && delete_installation || graceful_exit 1 "${ROLLBACK_FAILURE_MESSAGE}"
	[ "$(ls -A ${SSO_FULL_SYMLINK})" ] && graceful_exit 1 "Unable to clear ${SSO_FULL_SYMLINK}. Possible file ownership/permissions issue" \
	|| info "${SSO_FULL_SYMLINK} cleared"
	active_instance_action unlock
}

cleanup ()
{
	${ECHO} "Nothing to do for cleanup" > /dev/null 2>&1
}

##
## Exit gracfully so as not to break flow
##
graceful_exit ()
{
	[ "${#}" -gt 1 -a "${1}" -eq 0 ] && info "${2}"
	[ "${#}" -gt 1 -a "${1}" -gt 0 ] && error "${2}"
	cleanup
	exit ${1}
}

USAGE_ERR=1
case "$1" in
broken-install) if [ "$#" = 1 ]
				then
					USAGE_ERR=0
					is_installation_good && print_warning || do_rollback
				fi
				;;

force)       	if [ "$#" = 1 ]
				then
					USAGE_ERR=0
					do_rollback
				fi
				;;

unsafe)       	if [ "$#" = 1 ]
				then
					USAGE_ERR=0
					do_unsafe_rollback
				fi
				;;
esac

if (( USAGE_ERR > 0 ))
then
	print_usage
	graceful_exit 1
fi

graceful_exit 0
