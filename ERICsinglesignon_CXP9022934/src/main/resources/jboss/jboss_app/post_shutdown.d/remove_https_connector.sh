#!/bin/bash

ECHO="echo -e"
GREP=/bin/grep
BASENAME=/bin/basename
LOGGER=/usr/bin/logger
SSO_CONTAINER_PATTERN="SSO"
SCRIPT_NAME=$( ${BASENAME} ${0} )
HTTPS_CONNECTOR_FOUND=""
LOGGER_TAG="TOR_SSO"

container_check=$( ${ECHO} ${LITP_JEE_CONTAINER_instance_name} | ${GREP} ${SSO_CONTAINER_PATTERN} )
ret_val=${?}

##
## INFORMATION print
##
info()
{
	if [ ${#} -eq 0 ]; then
		while read data; do
			logger -s -t ${LOGGER_TAG} -p user.notice "INFORMATION ( ${SCRIPT_NAME} ): ${data}"
		done
	else
		logger -s -t ${LOGGER_TAG} -p user.notice "INFORMATION ( ${SCRIPT_NAME} ): $@"
	fi
}

##
## ERROR print
##
error()
{
	if [ ${#} -eq 0 ]; then
		while read data; do
			logger -s -t ${LOGGER_TAG} -p user.err "ERROR ( ${SCRIPT_NAME} ): ${data}"
		done
	else
		logger -s -t ${LOGGER_TAG} -p user.err "ERROR ( ${SCRIPT_NAME} ): $@"
	fi
}

##
## WARN print
##
warn()
{
	if [ ${#} -eq 0 ]; then
		while read data; do
			logger -s -t ${LOGGER_TAG} -p user.warning "WARN ( ${SCRIPT_NAME} ): ${data}"
		done
	else
		logger -s -t ${LOGGER_TAG} -p user.warning "WARN ( ${SCRIPT_NAME} ): $@"
	fi
}

##
## Function to add https connector and configure SSL
## Will use the default keystore presently - requires
## certificates to be added in advance
##
remove_https_connector()
{
$JBOSS_CLI << EOF
connect
/subsystem=web/connector=https:remove
EOF

	local L_HTTPS_CONNECTOR_FOUND=$( ${JBOSS_CLI} -c "/subsystem=web/connector=https:read-resource" | ${GREP} -io "success" )
	[ "${L_HTTPS_CONNECTOR_FOUND}" = "success" ] && return 1 || return 0
}

##
## Clean up function, nothing to do so far
##
cleanup ()
{
	info "No cleanup to be performed"
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

############
## EXECUTION
############
[ ${ret_val} -ne 0 ] && graceful_exit 0 "This is not the SSO container, skipping script execution" \
|| info "SSO Container found, checking for https web connector"

HTTPS_CONNECTOR_FOUND=$( ${JBOSS_CLI} -c "/subsystem=web/connector=https:read-resource" | ${GREP} -io "success" )

info "Result of https web connector check: ${HTTPS_CONNECTOR_FOUND}"

[ "${HTTPS_CONNECTOR_FOUND}" = "success" ] || graceful_exit 0 "Found no existing https web connector, no removal necessary"

info "Found https connector, removing"
remove_https_connector && graceful_exit 0 "Successfully removed https connector" \
|| graceful_exit 1 "Could not remove https connector from SSO JBoss"

exit 0