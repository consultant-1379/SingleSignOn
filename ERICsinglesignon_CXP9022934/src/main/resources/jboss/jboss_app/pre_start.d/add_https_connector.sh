#!/bin/bash

ECHO="echo -e"
GREP=/bin/grep
BASENAME=/bin/basename
LOGGER=/usr/bin/logger
SSO_CONTAINER_PATTERN="SSO"
SCRIPT_NAME=$( ${BASENAME} ${0} )
HTTPS_CONNECTOR_FOUND=""
KEYSTORE=/usr/java/default/jre/lib/security/cacerts
KEYTOOL=/usr/java/default/bin/keytool
KEY_PASS="changeit"
JBOSS_SERVER_CERT_ALIAS="sso-server"
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
## Will use the default keystore presently. Also used
## to increase the httpd connector thread pool
##
## Requires certificates to be added in advance (see
## functions update_root_ca and update_keystore)
##
add_https_connector()
{
$JBOSS_CLI << EOF
connect
/subsystem=web/connector=http:write-attribute(name=max-connections,value=30)
/subsystem=web/connector=https:add(socket-binding=https,scheme=https,protocol="HTTP/1.1",secure=true,max-connections=30)
/subsystem=web/connector=https/ssl=configuration:add(\
name="ssl",\
password="${KEY_PASS}",\
certificate-key-file="${KEYSTORE}",\
key-alias="${JBOSS_SERVER_CERT_ALIAS}")
/subsystem=threads/blocking-bounded-queue-thread-pool=http-executor:write-attribute(name=core-threads,value=15)
/subsystem=threads/blocking-bounded-queue-thread-pool=http-executor:write-attribute(name=max-threads,value=30)
/subsystem=threads/blocking-bounded-queue-thread-pool=http-executor:write-attribute(name=queue-length,value=15)
:reload
EOF

	# Confirm connector was added
	HTTPS_CONNECTOR_FOUND=$( ${JBOSS_CLI} -c "/subsystem=web/connector=https:read-resource" | ${GREP} -io "success" )

	info "Result of https web connector check: ${HTTPS_CONNECTOR_FOUND}"
	[ "${HTTPS_CONNECTOR_FOUND}" = "success" ] && return 0 || return 1
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
|| info "SSO Container found, executing script"

info "Attempting to add https connector to SSO JBoss instance"
add_https_connector && graceful_exit 0 "Successfully added https connector" || graceful_exit 1 "Could not add https connector to SSO JBoss"

exit 0
