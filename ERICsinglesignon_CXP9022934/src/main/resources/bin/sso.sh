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


##############
# Command vars
##############
GREP=/bin/grep
SED=/bin/sed
CAT=/bin/cat
ECHO="echo -e"
AWK=/bin/awk
FIND=/bin/find
CURL=/usr/bin/curl
AMF_ADM=/usr/bin/amf-adm
AMF_FIND=/usr/bin/amf-find
GLOBAL_PROPERTIES=/ericsson/tor/data/global.properties
LOCAL_PROPERTIES=/opt/ericsson/sso/etc/env-vars.conf
SCRIPT_NAME=`basename $0`
AMPASSWORD=/opt/ericsson/sso/openam-tools/admin/heimdallr/bin/ampassword
RM=/bin/rm
CP=/bin/cp
STAT=/usr/bin/stat
AM_ACCESS_FILE_LENGTH=9
LDAP_PW_KEY="COM_INF_LDAP_ADMIN_ACCESS"


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
JAVA_HOME=${SSO_INSTALL_JAVA_HOME}
SSO_BIN_DIR=${SSO_HOME}/bin
SSO_CONF_DIR=${SSO_HOME}/etc
SANITY_CHECK=${SSO_BIN_DIR}/sanity-check.sh
SSO_SYSTEM_CHECK="${CURL} --max-time 5 -s -L -w %{http_code} -o /dev/null ${SSO_HEARTBEAT_JBOSS}"
SSOADM_FILE=${SSO_SSOADM_HOME}/${SSO_DEPLOYMENT_NAME}/bin/ssoadm
SSOADM=${SSO_SSOADM_HOME}/${SSO_DEPLOYMENT_NAME}/bin/ssoadm
SSO_ADMIN_NAME=amadmin
REFERRAL_VALUE=o=$REALM_NAME,ou=services,$DATA_STORE_ROOT_SUFFIX
SYSTEM_LOG_FILE=/var/log/messages
SSO_CONFIGURATOR_OPTIONS=/tmp/configurator.conf
SSO_UPGRADE_OPTIONS=/tmp/upgrade.conf
SSO_BATCH_CONFIG=/tmp/batch.conf
SSO_TEMP_UPDATE_CONFIG=/tmp/batch-update.conf
SSO_UPDATE_CONF_DIR=${SSO_HOME}/etc/updates
SSO_REFERRAL_TEMP_FILE=/tmp/${REALM_NAME}-referral.xml
SSO_POLICY_TEMP_FILE=/tmp/${REALM_NAME}-policy.xml
SSO_REFERRAL_UPDATE_FILE=/tmp/referral-update.xml
SSO_POLICY_UPDATE_FILE=/tmp/policy-update.xml
SSO_AGENT_ATTRIBUTES_FILE=/tmp/agent-attributes.conf
TMP_FILES="${SSO_CONFIGURATOR_OPTIONS} ${SSO_UPGRADE_OPTIONS} ${SSO_BATCH_CONFIG} ${SSO_AGENT_ATTRIBUTES_FILE} \
${SSO_REFERRAL_TEMP_FILE} ${SSO_POLICY_TEMP_FILE} ${SSO_TEMP_UPDATE_CONFIG} ${SSO_REFERRAL_UPDATE_FILE} ${SSO_POLICY_UPDATE_FILE}"

#############
# FUNCTIONS #
#############
##
## Print simple command usage info
##
print_usage ()
{
	${ECHO} "Invalid command: $0 $*"
	${ECHO} "Usage: $0 {checkenv | config | config <options> | init | status | upgrade}"
}

##
## Check the exit value from the last command and return 1 if it failed.
##
check_exit_value ()
{
	if [ $? -ne 0 ]
	then
		graceful_exit 1 "${1}"
	fi
}

##
## Remove a file or a directory
##
remove_file ()
{
	#-- remove backupfile --#
	rm -rf "$1" 2>/dev/null
	check_exit_value "Could not remove [ ${1} ]"
}

##
## Create a new dms_sso backup directory
##
create_directory ()
{
	mkdir -p "$1"
	check_exit_value "Could not create [ ${1} ]"
	info "${1} has been created"
}

##
## Helper function to test if a file exists
##
does_file_exist ()
{
	[ -f "${1}" ] && info "File ${1} already exists, it will be overwritten"
	return 0
}

##
## Options file needed for initialising
##
## When AM_ENC_KEY is left blank, an encoding key will be generated
## automatically for transmitting sensitive info over http
##
## This configuration uses the embedded OpenDS instance as the
## "configuration store" (separate from the user store)
create_configurator_options ()
{
	# Find the locale, if set. Otherwise use a default value
	local l_local="en_US"
	[ "x${LANG}" != "x" ] && l_locale=` ${ECHO} ${LANG} | cut -f1 -d. `

	does_file_exist ${SSO_CONFIGURATOR_OPTIONS}
	${CAT} << EOF > ${SSO_CONFIGURATOR_OPTIONS}
SERVER_URL=${OPENAM_SERVER_URL}
DEPLOYMENT_URI=${SSO_DEPLOYMENT_NAME}
BASE_DIR=${SSO_FULL_SYMLINK}
locale=${l_local}
PLATFORM_LOCALE=${l_local}
AM_ENC_KEY=
ADMIN_PWD=` ${CAT} ${AM_ACCESS_FILE} `
AMLDAPUSERPASSWD=` ${CAT} ${AM_POLICY_ACCESS_FILE} `
COOKIE_DOMAIN=${SSO_COOKIE_DOMAIN}

DATA_STORE=embedded
DIRECTORY_SSL=SIMPLE
DIRECTORY_SERVER=${AM_SERVER}
DIRECTORY_PORT=${SSO_DIRECTORY_PORT}
DIRECTORY_ADMIN_PORT=${SSO_DIRECTORY_ADMIN_PORT}
DIRECTORY_JMX_PORT=${SSO_DIRECTORY_JMX_PORT}
ROOT_SUFFIX=${DATA_STORE_ROOT_SUFFIX}
DS_DIRMGRDN=cn=Directory Manager
DS_DIRMGRPASSWD=` ${CAT} ${AM_CONFIG_ACCESS_FILE} `

USERSTORE_TYPE=LDAPv3ForOpenDS
USERSTORE_SSL=${LDAP_SSL}
USERSTORE_HOST=${COM_INF_LDAP_HOST_1}
USERSTORE_PORT=${COM_INF_LDAP_PORT}
USERSTORE_SUFFIX=${COM_INF_LDAP_ROOT_SUFFIX}
USERSTORE_MGRDN=cn=${COM_INF_LDAP_ADMIN_CN}
USERSTORE_PASSWD=${COM_INF_LDAP_ADMIN_ACCESS}
EOF
	[ -f ${SSO_CONFIGURATOR_OPTIONS} ] && return 0 || return 1
}

##
## Options file needed for upgrade
##
create_upgrade_options ()
{
	does_file_exist ${SSO_UPGRADE_OPTIONS}
	${CAT} << EOF > ${SSO_UPGRADE_OPTIONS}
SERVER_URL=${OPENAM_SERVER_URL}
DEPLOYMENT_URI=${SSO_DEPLOYMENT_NAME}
EOF
	[ -f ${SSO_UPGRADE_OPTIONS} ] && return 0 || return 1
}

create_agent_options ()
{
	does_file_exist ${SSO_AGENT_ATTRIBUTES_FILE}
	${CAT} << EOF > ${SSO_AGENT_ATTRIBUTES_FILE}
com.sun.identity.agents.config.login.url[0]=${AGENT_SERVER_URL}/login/
com.sun.identity.agents.config.logout.url[0]=${AGENT_SERVER_URL}/logout
com.sun.identity.agents.config.agent.logout.url[0]=${AGENT_SERVER_URL}/logout
com.sun.identity.agents.config.logout.redirect.url=${AGENT_SERVER_URL}/login
com.sun.identity.agents.config.notenforced.url[0]=${AGENT_SERVER_URL}/login*
com.sun.identity.agents.config.notenforced.url[1]=${AGENT_SERVER_URL}/login*?*
com.sun.identity.agents.config.notenforced.url[2]=${AGENT_SERVER_URL}/heimdallr*
com.sun.identity.agents.config.notenforced.url[3]=${AGENT_SERVER_URL}/heimdallr*?*
com.sun.identity.agents.config.notenforced.url[4]=${AM_PROTOCOL}://${SSO_MACHINE_NAME}:8666*
com.sun.identity.agents.config.debug.file.rotate=false
com.sun.identity.agents.config.auth.connection.timeout=10
com.sun.identity.agents.config.notenforced.uri.cache.enable=true
com.sun.identity.agents.config.notenforced.uri.cache.size=10000
com.sun.identity.agents.config.fqdn.check.enable=false
com.sun.identity.agents.config.debug.file.size=200000000
EOF
	
	[ -f ${SSO_AGENT_ATTRIBUTES_FILE} ] && return 0 || return 1
}

##
## Batch configuration file for ssoadm
##
## Common options to all "ssoadm" commands are -u for admin username and 
## -f for the admin password file. Most of the ssoadm commands can be
## grouped in a batch file and passed as one "do-batch" command
##
## Configurations covered here:
##    Realm creation (logical grouping of policies and agent profiles)
##    Access policies and their "referrals" (for when policies exist in a
##       sub-realm as they do here) for protecting web resources
##    Agent profiles for TOR apps and OSS-RC webapps
##       Profiles need server urls, login and logout resource urls, a list of urls
##       not enforced by the Policy Agent
##    Adding a 2nd LDAP instance (taken from ${GLOBAL_PROPERTIES})
##    Session timeout and idle values
##
## Only separate config needed is to get the DATASTORE_NAME from the config store
create_batch_config ()
{
	does_file_exist ${SSO_BATCH_CONFIG}
		# need tp get the Datastore 'type'
		local DATASTORE_NAME="OpenDJ"
		${CAT} << EOF > ${SSO_BATCH_CONFIG}
create-realm -e ${REALM_NAME}
create-policies -e / -X ${SSO_REFERRAL_TEMP_FILE}
create-policies -e /${REALM_NAME} -X ${SSO_POLICY_TEMP_FILE}
create-agent -e /${REALM_NAME} -b ${SSO_AGENT_NAME} -t WebAgent -s ${OPENAM_SERVER_URL}/${SSO_DEPLOYMENT_NAME} -g ${AGENT_SERVER_URL} -a "userpassword=` ${CAT} ${SSO_AGENT_ACCESS_FILE} `"
update-agent -e /${REALM_NAME} -b ${SSO_AGENT_NAME} -D ${SSO_AGENT_ATTRIBUTES_FILE}
update-datastore -e / -m ${DATASTORE_NAME} -a "sun-idrepo-ldapv3-config-ldap-server=${COM_INF_LDAP_HOST_1}:${COM_INF_LDAP_PORT}" "sun-idrepo-ldapv3-config-ldap-server=${COM_INF_LDAP_HOST_2}:${COM_INF_LDAP_PORT}"
update-datastore -e /${REALM_NAME} -m ${DATASTORE_NAME} -a "sun-idrepo-ldapv3-config-ldap-server=${COM_INF_LDAP_HOST_1}:${COM_INF_LDAP_PORT}" "sun-idrepo-ldapv3-config-ldap-server=${COM_INF_LDAP_HOST_2}:${COM_INF_LDAP_PORT}"
add-svc-realm -e / -s iPlanetAMSessionService
set-realm-svc-attrs -e / -s iPlanetAMSessionService -a "iplanet-am-session-max-session-time=600" "iplanet-am-session-max-idle-time=60"
update-server-cfg -s default -a "com.iplanet.am.session.maxSessions=100000"
EOF
	[ -f ${SSO_BATCH_CONFIG} ] && return 0 || return 1
}

##
## Create localised policy definitions from template xml files
##
customise_policy_templates ()
{

	does_file_exist ${SSO_REFERRAL_TEMP_FILE}
	does_file_exist ${SSO_POLICY_TEMP_FILE}

	# Make copies of the templates
	cp -f ${SSO_SSOADM_HOME}/template-referral.xml ${SSO_REFERRAL_TEMP_FILE}
	cp -f ${SSO_SSOADM_HOME}/template-policy.xml ${SSO_POLICY_TEMP_FILE}

	[ -f ${SSO_REFERRAL_TEMP_FILE} -a -f ${SSO_POLICY_TEMP_FILE} ] || return 1

	# Replace the placeholder strings
	${SED} -i "s|placeholder.referral.policy.name|${REALM_NAME}-referral|g;\
	s|placeholder.referral.policy.rule.name|${REALM_NAME}-referral-policy-rule|g;\
	s|placeholder.apache.agent.url|${AGENT_SERVER_URL}|g;\
	s|placeholder.oss.tomcat.agent.url|${OSS_TOMCAT_AGENT_SERVER_URL}|g;
	s|placeholder.referral.rule.name|${REALM_NAME}-referral-rule|g;
	s|placeholder.referral.value|${REFERRAL_VALUE}|g" ${SSO_REFERRAL_TEMP_FILE}
	${SED} -i "s|placeholder.policy.name|${REALM_NAME}-policy-all|g;\
	s|placeholder.policy.rule.name|${REALM_NAME}-policy-all-rule|g;\
	s|placeholder.apache.agent.url|${AGENT_SERVER_URL}|g;\
	s|placeholder.oss.tomcat.agent.url|${OSS_TOMCAT_AGENT_SERVER_URL}|g;\
	s|placeholder.policy.subject.name|${REALM_NAME}-policy-all-subject|g" ${SSO_POLICY_TEMP_FILE}

	return 0
}

##
## Perform a sanity check of the environment
##
checkenv ()
{
	FAILURE_MESSAGE="Environment check failed. Cannot proceed with Single Sign On initialisation until"
	FAILURE_MESSAGE="${FAILURE_MESSAGE} environment is setup correctly. Check ${SYSTEM_LOG_FILE} for entries"
	FAILURE_MESSAGE="${FAILURE_MESSAGE} tagged with ${SANITY_CHECK}"
	info "Performing sanity check on environment"
	${SANITY_CHECK} || graceful_exit 5 ${FAILURE_MESSAGE}
	info "Sanity check successfully completed"
	return 0
}

##
## Show the status of SSO - call check_system() and report back
##
check_status ()
{
	if check_system; then
		${ECHO} "Single Sign On system is running"
		return 0
	else
		${ECHO} "Single Sign On system not running. Check ${SYSTEM_LOG_FILE} entries tagged with ${SCRIPT_NAME} and run ${SANITY_CHECK} for possible reasons"
		graceful_exit 1
	fi
}

##
## Check the installation of OpenAM - this is an offline function
## checking for the presence of SSO configuration
##
check_for_installation ()
{
	FAILURE_MESSAGE="Incomplete SSO installation detected."
	FAILURE_MESSAGE="${FAILURE_MESSAGE} Lock the SSO JBoss instance on this machine, remove the contents (including hidden files!)"
	FAILURE_MESSAGE="${FAILURE_MESSAGE} of ${SSO_FULL_SYMLINK} and unlock the JBoss instance to attempt re-install SSO"
	info "Checking for existing SSO installation"
	[ -f ${SSO_FULL_SYMLINK}/bootstrap ] && return 1
	[ -d ${SSO_FULL_SYMLINK}/opends -a ! -f ${SSO_FULL_SYMLINK}/bootstrap ] && graceful_exit 1 "${FAILURE_MESSAGE}"
	info "No previous installation of SSO found, continuing with initialisation"
	return 0
}

##
## Quick check of the deployment url
##
check_deployment ()
{
	local ret_val=`${SSO_SYSTEM_CHECK}` > /dev/null 2>&1
	[ "${ret_val}" = "200" -o "${ret_val}" = "500" ] || graceful_exit 1 "Could not reach SSO deployment at ${OPENAM_SERVER_URL}. Check the JBoss logs of the SSO instance on this machine"
	return 0
}

##
## Check the status of the Single Sign On installation
## specifcally for the ssoadm command
##
check_system ()
{
	ret_val=`${SSO_SYSTEM_CHECK}` > /dev/null 2>&1
	check_exit_value "Couldn't contact Single Sign On server. Possible reasons are the SSO JBoss container is not running, the SSO host at ${AM_SERVER} is not reachable from this machine or it's IP address is incorrect"
	if [ "${ret_val}" -ne 200 ]; then
		error "Single Sign On system check failed. Checking for bootstrap file"
		if [ ! -f $SSO_FULL_SYMLINK/bootstrap ]; then
			error "Single Sign On system is not configured. Please run ${SCRIPT_NAME} init"
		else
			error "SSO seems to be installed but not currently running."
		fi
		return 1

	fi
	if [ ! -x "${SSOADM_FILE}" ]; then
		if [ ! -f "${SSOADM_FILE}" ]; then
			error "SSO command line tool has not been installed. Single Sign On needs to be installed and configured for this command to be available"
			return 1
		fi
		error "SSO command line tool not setup correctly. Make sure the file ${SSOADM_FILE} exists and is executable"
		return 1
	fi
	return 0
}

##
## Initialise Single Sign On with default options
## defined in the config file created above
##
do_init ()
{
	info "Initialising Single Sign On"
	check_for_installation || graceful_exit 10 "Installation of SSO detected, aborting initialisation"
	info "Performing sanity check on evnironment"
	checkenv
	info "Sanity check passed, continuing with initialisation"
	check_deployment && info "${SSO_NAME}.war is deployed. Creating initialisation options"
	create_configurator_options || graceful_exit 1 "Could not create configuration options file ${SSO_CONFIGURATOR_OPTIONS}, cannot continue"
	info "Attempting to initialise SSO"
	${JAVA_HOME}/bin/java -jar ${SSO_CONFIGURATOR_HOME}/configurator.jar -f ${SSO_CONFIGURATOR_OPTIONS}
	check_for_installation && graceful_exit 1 "SSO initialisation unsuccessful, cancelling configuration"
	info "SSO initialisation successful, installing command line tools"
	install_admin_tools || graceful_exit 1 "SSO command line tools installation failed, aborting configuration"
	config_default
	info "SSO installation complete"
	return 0
}

install_admin_tools ()
{
	cd ${SSO_SSOADM_HOME}
	[ -x ./setup ] || chmod +x ./setup
	JAVA_HOME=${JAVA_HOME} ./setup -p $SSO_FULL_SYMLINK -d $SSO_SSOADM_HOME/debug -l $SSO_SSOADM_HOME/log
	cd - >> /dev/null
	[ -f ${SSOADM} ] || graceful_exit 1 "Command line tools were not installed. SSO initialisation may have failed"
	return 0
}

check_default_config_exists ()
{
	info "Checking for presence of default configuration"
	config_custom list-realms -e / | ${GREP} ${REALM_NAME} > /dev/null 2>&1
	[ ${?} -eq 0 ] && return 0
	info "No baseline configuration detected, proceeding with default configuration"
	return 1
}
##
## Perform the base configuration of Single Sign On (including
## the setup of the admin command-line tool)
##
config_default ()
{
	check_default_config_exists && graceful_exit 1 "SSO Baseline configuration exists, aborting default config operation"
	info "Configuring Single Sign On with baseline configuration"
	info "Creating policy files"
	customise_policy_templates || graceful_exit 1 "Could not create policy files, cannot continue"
	info "Creating batch configuration file"
	create_agent_options || graceful_exit 1 "Could not create configuration options file ${SSO_AGENT_ATTRIBUTES_FILE}, cannot continue"
	create_batch_config || graceful_exit 1 "Could not create configuration options file ${SSO_BATCH_CONFIG}, cannot continue"
	info "Beginning batch configuration"
	cd ${SSO_SSOADM_HOME}
	config_custom do-batch -Z ${SSO_BATCH_CONFIG} --continue -v && info "Batch configuration complete" \
	|| error "Batch configuration failed. Configuration can be run later, or can be restored from a backup"
	cd - >> /dev/null
	return 0
}

##
## Perform custom configuration - this is a wrapper to the
## "ssoadm" command provided by OpenAM
##
config_custom ()
{
	info "Configuring Single Sign On with custom options: $*"
	check_system
	check_exit_value "Could not perform custom configuration"
	if [[ ${1} == \-* ]]; then
		${ECHO} "First argument must be the ssoadm sub-command, e.g., ${SCRIPT_NAME} config list-agents -e /${REALM_NAME}\n"
		print_usage
		graceful_exit 1
	fi
	JAVA_HOME=${JAVA_HOME} ${SSOADM} ${@} -u ${SSO_ADMIN_NAME} -f ${AM_ACCESS_FILE}
	return 0
}


##
## Encrypt the ssoadm password file and delete the Embedded LDAP password file
## Called at the end of SSO configuration from JBoss App Post Start script
##
encrypt_and_clean_password_files()
{
	info "Cleaning passwords"

	##
	## Password is immutable and so the length is known. If the password changes, the
	## value of ${AM_ACCESS_FILE_LENGTH} will have to change with it
	##
	# if [ $( ${STAT} -c %s "${SSO_CONF_DIR}"/access.bin ) -gt ${AM_ACCESS_FILE_LENGTH} ]; then
	# 	info "Password file is already encrypted"
	# else
	# 	${CP} -f ${SSO_CONF_DIR}/access.bin ${SSO_CONF_DIR}/access.bin.orig
	# 	${RM} -f ${SSO_CONF_DIR}/access.bin
	# 	${AMPASSWORD} -e ${SSO_CONF_DIR}/access.bin.orig > ${SSO_CONF_DIR}/access.bin
	# 	chmod 400 ${SSO_CONF_DIR}/access.bin
	# 	${RM} -f ${SSO_CONF_DIR}/access.bin.orig
	# fi

	${RM} -f ${SSO_CONF_DIR}/config-access.bin
	${RM} -f ${SSO_CONF_DIR}/policy-access.bin

	if [ -d "${SSO_HOME}"/web_agents/apache22_agent/Agent_??? -a -f "${SSO_CONF_DIR}/agent-access.bin" ]; then
		info "Policy Agent installed but password file remains, removing"
		${RM} -f ${SSO_CONF_DIR}/agent-access.bin
	fi

	#info "Cleaning LDAP password"
	#${SED} -i "/${LDAP_PW_KEY}/ s/=.*$/=xxxx/g" ${GLOBAL_PROPERTIES}

	info "Encryption complete"
}

update_config ()
{
	for batch_file in $( ${FIND} ${SSO_UPDATE_CONF_DIR} -name "*.conf" ); do
		info "Found config update file ${batch_file}"
		while read line; do
			eval ${ECHO} "${line}" >> ${SSO_TEMP_UPDATE_CONFIG}
		done < ${batch_file}
	done

	if [ -f ${SSO_TEMP_UPDATE_CONFIG} ]; then
		info "Running batch configuration update"
		cd ${SSO_SSOADM_HOME}
		config_custom do-batch -Z ${SSO_TEMP_UPDATE_CONFIG} --continue -v
		update_ret_val=${?}
		cd - >> /dev/null
		if [ ${update_ret_val} -eq 0 ]; then
			info "Batch configuration update complete, removing config files"
			${RM} -f ${SSO_UPDATE_CONF_DIR}/*.conf
			return 0
		else
			graceful_exit 1 "Batch configuration updates failed. Check /var/log/litp/litp_jboss.log for errors from ${SCRIPT_NAME}"
		fi

	else
		info "No configuration updates found"
	fi
}

##
## Perform an upgrade of the OpenAM war file using
## OpenAM's own upgrade procedure
##
do_upgrade ()
{
	info "Checking for configuration updates"
	update_config
	info "Upgrading Single Sign On"
	create_upgrade_options || graceful_exit 1 "Could not create configuration options file ${SSO_UPGRADE_OPTIONS}, cannot continue"
	info "Attempting upgrade"
	${JAVA_HOME}/bin/java -jar ${SSO_CONFIGURATOR_HOME}/upgrade.jar -f ${SSO_UPGRADE_OPTIONS} > /dev/null 2>&1
	check_exit_value "Upgrade could not be performed"
	info "Securing SSO"
	encrypt_and_clean_password_files
	info "Upgrade complete"
	return 0
}

##
## Clean up function to remove temporary files
##
cleanup ()
{
	for i in ${TMP_FILES}; do
		remove_file ${i}
	done
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
status) 		if [ "$#" = 1 ]
				then
					USAGE_ERR=0
					check_status
				fi
;;

checkenv)		if [ "$#" = 1 ]
				then
					USAGE_ERR=0
					checkenv
				fi
;;

init)			if [ "$#" = 1 ]
				then
					USAGE_ERR=0
					do_init
				fi
;;

config)			if [ "$#" = 1 ]
				then
					USAGE_ERR=0
					config_default
				elif [ "$#" -gt 1 ]
					then
					USAGE_ERR=0
					shift
					config_custom "$@"
				fi
;;

upgrade)		if [ "$#" = 1 ]
				then
					USAGE_ERR=0
					do_upgrade
				fi
;;
esac

if (( USAGE_ERR > 0 ))
	then
	print_usage
	graceful_exit 1
fi

graceful_exit 0
