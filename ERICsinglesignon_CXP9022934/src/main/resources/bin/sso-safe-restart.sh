#!/bin/bash

##
## Script to safely restart SSO Apache and JBoss instances
## with minimum downtime
##	

##
## COMMANDS
##
AMF_ADM=/usr/bin/amf-adm
AMF_FIND=/usr/bin/amf-find
AMF_STATE=/usr/bin/amf-state
AWK=/bin/awk
BASENAME=/bin/basename
ECHO="echo -e"
GREP=/bin/grep
HAGRP=/opt/VRTSvcs/bin/hagrp
LOGGER=/usr/bin/logger
RM=/bin/rm

##
## PATHS
##

##
## ENVIRONMENT
##
ACTIVE_APACHE_SU=$( ${AMF_STATE} su all | ${AWK} -v RS='safSu=' '/httpd/ && /=INSTANTIATED/ {print RS$1}' )
ACTIVE_JBOSS_HOST=$( ${HAGRP} -state | ${AWK} -v host=${HOSTNAME} '/apache/ && /ONLINE/ {print $3}' )
ACTIVE_JBOSS_SU_NUM=$( ${HAGRP} -state | ${AWK} -v ssohost=${ACTIVE_JBOSS_HOST} '$0 ~ ssohost && /SSO/ && /ONLINE/ {gsub(/[^0-9]/,"",$1);print $1}' )
ACTIVE_JBOSS_SU=$( ${AMF_FIND} su all | ${AWK} -v activenum=${ACTIVE_JBOSS_SU_NUM} '/SSO/ && $0 ~ activenum' )
INACTIVE_APACHE_SU=$( ${AMF_STATE} su all | ${AWK} -v RS='safSu=' '/httpd/ && /=UNINSTANTIATED/ {print RS$1}' )
INACTIVE_JBOSS_HOST=$( ${HAGRP} -state | ${AWK} -v host=${HOSTNAME} '/apache/ && /OFFLINE/ {print $3}' )
INACTIVE_JBOSS_SU_NUM=$( ${HAGRP} -state | ${AWK} -v ssohost=${INACTIVE_JBOSS_HOST} '$0 ~ ssohost && /SSO/ && /ONLINE/ {gsub(/[^0-9]/,"",$1);print $1}' )
INACTIVE_JBOSS_SU=$( ${AMF_FIND} su all | ${AWK} -v inactivenum=${INACTIVE_JBOSS_SU_NUM} '/SSO/ && $0 ~ inactivenum' )
LOGGER_TAG="TOR_SSO"
SCRIPT_NAME=$( ${BASENAME} ${0} )

##
## ENVIRONMENT CHECK
##
FILES_TO_CHECK=""

## CLEANUP
##
FILES_TO_REMOVE=""

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
## Check all necessary files for execution exist,
## exit with error if otherwise
##
check_files_exist()
{
	[ -z "${FILES_TO_CHECK}" ] && return 0

	local L_FILES_NOT_THERE=""

	info "Checking for files: ${FILES_TO_CHECK}"
	for file_to_check in "${FILES_TO_CHECK}"; do
		[ ! -f ${file_to_check} ] && L_FILES_NOT_THERE="${L_FILES_NOT_THERE} ${file_to_check}"
	done

	[ ! -z "${L_FILES_NOT_THERE}" ] && ( info "Files missing: ${L_FILES_NOT_THERE}. Using existing certificate configuration."; return 1 )
	info "All certificate files present"

	return 0
}

cleanup ()
{
	local L_FILES_NOT_REMOVED=""

	if [ ! -z "${FILES_TO_REMOVE}" ]; then
		info "Removing temporary files"
		for temp_file in ${FILES_TO_REMOVE}; do
			if [ -f ${temp_file} ]; then
				${RM} -f ${temp_file} && info "Removed ${temp_file}" || ${L_FILES_NOT_REMOVED}="${L_FILES_NOT_REMOVED} ${temp_file}"
			fi
		done
	else
		info "No temporary files to remove"
	fi

	[ ! -z ${L_FILES_NOT_REMOVED} ] && info "Some files not removed, not fatal: ${L_FILES_NOT_REMOVED}" || info "Clean up complete"
	
	return 0
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

##
## EXECUTION
##
## Procedure:
## 1. Lock and unlock inactive JBoss
## 2. Lock and unlock active Apache
## 3. Lock and unlock other JBoss
## 4. Lock and unlock other Apache
##
info "Safe restart of SSO instances commencing"
${ECHO} "\nAttempting to restart Apache and SSO JBoss service units"
${ECHO} "This may take a couple of minutes"

${ECHO} "\nRestarting inactive JBoss instance ${INACTIVE_JBOSS_SU}"
${ECHO} "Locking ${INACTIVE_JBOSS_SU}"
${AMF_ADM} lock ${INACTIVE_JBOSS_SU}
ret_val=${?}
${ECHO} "Waiting for state UNINSTANTIATED of ${INACTIVE_JBOSS_SU}"
until ${AMF_STATE} su pres ${INACTIVE_JBOSS_SU} | ${GREP} "=UNINSTANTIATED"; do
	sleep 1
done

${ECHO} "Waiting 5 seconds..."
sleep 5
# if [ ${ret_val} -ne 0 ]; then
# 	${ECHO} "\nCould not lock ${INACTIVE_JBOSS_SU}. Exiting"
# 	graceful_exit 1 "Failed to lock ${INACTIVE_JBOSS_SU}"
# fi








${ECHO} "Unlocking ${INACTIVE_JBOSS_SU}"
${AMF_ADM} unlock ${INACTIVE_JBOSS_SU}
ret_val=${?}
${ECHO} "Waiting for state INSTANTIATED of ${INACTIVE_JBOSS_SU}"
until ${AMF_STATE} su pres ${INACTIVE_JBOSS_SU} | ${GREP} "=INSTANTIATED"; do
	sleep 1
done

${ECHO} "Waiting 5 seconds..."
sleep 5

# if [ ${?} -ne 0 ]; then
# 	${ECHO} "\nCould not unlock ${INACTIVE_JBOSS_SU}. Exiting"
# 	graceful_exit 1 "Failed to unlock ${INACTIVE_JBOSS_SU}"
# fi











${ECHO} "\nRestarting active Apache instance ${ACTIVE_APACHE_SU}"
${ECHO} "Locking ${ACTIVE_APACHE_SU}"
${AMF_ADM} lock ${ACTIVE_APACHE_SU}
ret_val=${?}
${ECHO} "Waiting for state INSTANTIATED of ${INACTIVE_APACHE_SU}"
until ${AMF_STATE} su pres ${INACTIVE_APACHE_SU} | ${GREP} "=INSTANTIATED"; do
	sleep 1
done

${ECHO} "Waiting 5 seconds..."
sleep 5

# if [ ${?} -ne 0 ]; then
# 	${ECHO} "\nCould not lock ${ACTIVE_APACHE_SU}. Exiting"
# 	graceful_exit 1 "Failed to lock ${ACTIVE_APACHE_SU}"
# fi



${ECHO} "Unlocking ${ACTIVE_APACHE_SU}"
${AMF_ADM} unlock ${ACTIVE_APACHE_SU}
ret_val=${?}
${ECHO} "Waiting for state IN-SERVICE of ${ACTIVE_APACHE_SU}"
until ${AMF_STATE} su readi ${ACTIVE_APACHE_SU} | ${GREP} "IN-SERVICE"; do
	sleep 1
done

# if [ ${?} -ne 0 ]; then
# 	${ECHO} "\nCould not unlock ${ACTIVE_APACHE_SU}. Exiting"
# 	graceful_exit 1 "Failed to unlock ${ACTIVE_APACHE_SU}"
# fi







${ECHO} "\nRestarting other JBoss instance ${ACTIVE_JBOSS_SU}"
${ECHO} "Locking ${ACTIVE_JBOSS_SU}"
${AMF_ADM} lock ${ACTIVE_JBOSS_SU}
ret_val=${?}
${ECHO} "Waiting for state UNINSTANTIATED of ${ACTIVE_JBOSS_SU}"
until ${AMF_STATE} su pres ${ACTIVE_JBOSS_SU} | ${GREP} "=UNINSTANTIATED"; do
	sleep 1
done

${ECHO} "Waiting 5 seconds..."
sleep 5

# if [ ${?} -ne 0 ]; then
# 	${ECHO} "\nCould not lock ${ACTIVE_JBOSS_SU}. Exiting"
# 	graceful_exit 1 "Failed to lock ${ACTIVE_JBOSS_SU}"
# fi








${ECHO} "Unlocking ${ACTIVE_JBOSS_SU}"
${AMF_ADM} unlock ${ACTIVE_JBOSS_SU}
ret_val=${?}
${ECHO} "Waiting for state INSTANTIATED of ${ACTIVE_JBOSS_SU}"
until ${AMF_STATE} su pres ${ACTIVE_JBOSS_SU} | ${GREP} "=INSTANTIATED"; do
	sleep 1
done

${ECHO} "Waiting 5 seconds..."
sleep 5

# if [ ${?} -ne 0 ]; then
# 	${ECHO} "\nCould not unlock ${ACTIVE_JBOSS_SU}. Exiting"
# 	graceful_exit 1 "Failed to unlock ${ACTIVE_JBOSS_SU}"
# fi












${ECHO} "\nRestarting other Apache instance ${INACTIVE_APACHE_SU}"
${ECHO} "Locking ${INACTIVE_APACHE_SU}"
${AMF_ADM} lock ${INACTIVE_APACHE_SU}
ret_val=${?}
${ECHO} "Waiting for state INSTANTIATED of ${ACTIVE_APACHE_SU}"
until ${AMF_STATE} su pres ${ACTIVE_APACHE_SU} | ${GREP} "=INSTANTIATED"; do
	sleep 1
done

${ECHO} "Waiting 5 seconds..."
sleep 5

# if [ ${?} -ne 0 ]; then
# 	${ECHO} "\nCould not lock ${INACTIVE_APACHE_SU}. Exiting"
# 	graceful_exit 1 "Failed to lock ${INACTIVE_APACHE_SU}"
# fi









${ECHO} "Unlocking ${INACTIVE_APACHE_SU}"
${AMF_ADM} unlock ${INACTIVE_APACHE_SU}
ret_val=${?}
${ECHO} "Waiting for state IN-SERVICE of ${INACTIVE_APACHE_SU}"
until ${AMF_STATE} su readi ${INACTIVE_APACHE_SU} | ${GREP} "IN-SERVICE"; do
	sleep 1
done

# if [ ${?} -ne 0 ]; then
# 	${ECHO} "\nCould not unlock ${INACTIVE_APACHE_SU}. Exiting"
# 	graceful_exit 1 "Failed to unlock ${INACTIVE_APACHE_SU}"
# fi









${ECHO} "Safe restart of SSO instances complete"
graceful_exit 0 "Restarted all Apache and SSO JBoss instances"

