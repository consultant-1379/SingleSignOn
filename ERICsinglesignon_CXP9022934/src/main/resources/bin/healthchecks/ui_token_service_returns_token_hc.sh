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
## Script to check whether the "Security Service" requestToken() function
## is working
##
## returns: 0 if the ClearPassword field is non-empty
##          1 if the CleanPassword field is empty or the curl request fails

##
## COMMON FUNCTIONS AND VARS
##
. /opt/ericsson/sso/bin/healthchecks/healthcheck_common.bsh

##
## COMMANDS
##

##
## PATHS
##

##
## ENVIRONMENT
##
AWK_SEARCH_PROPERTY="address"
CITRIX_APP_PATTERN="OSS_Common_Explorer"
CURL_COMMAND=""
CURL_HEADER="X-Tor-UserID:anonymous"
JBOSS_ROOT=/home/jboss
LITP_COMPONENT_NAME=UI
LITP_TREE_BASE=/inventory/deployment1/cluster1
LITP_URL=${LITP_TREE_BASE}/${LITP_COMPONENT_NAME}
LITP_SU_ERROR_LIST=""
LITP_SU_LIST=$( ${LS} -A ${JBOSS_ROOT} | ${AWK} '/UI/' | ${GREP} -o su_[0-9][0-9]* )
LITP_SU_SUCCESS_LIST=""
LITP_FULL_URL=""
NODE_NAME=$( ${CAT} /etc/cluster/nodes/this/hostname )
SCRIPT_NAME=$( ${BASENAME} ${0} )
UI_INSTANCE_IP_ADDRESS=""

##
## FUNCTIONS
##
##
## Clean up function to remove temporary files
##
cleanup ()
{
	for i in ${TMP_FILES}; do
		info ${SCRIPT_NAME} "No cleanup needed"
	done
}

##
## Exit gracefully so as not to break flow
##
graceful_exit ()
{
	[ "${#}" -gt 1 -a "${1}" -eq 0 ] && info ${SCRIPT_NAME} "${2}"
	[ "${#}" -gt 1 -a "${1}" -gt 0 ] && error ${SCRIPT_NAME} "${2}"
	#cleanup
	exit ${1}
}

##
## EXECUTION
##
for ui_instance in ${LITP_SU_LIST}; do
	LITP_FULL_URL="${LITP_TREE_BASE}/${LITP_COMPONENT_NAME}/${ui_instance}/jee/instance/ip/"
	UI_INSTANCE_IP_ADDRESS=$( ${LITP} ${LITP_FULL_URL} property ${AWK_SEARCH_PROPERTY} | ${AWK} -v addr=${AWK_SEARCH_PROPERTY} '$0 ~ addr {gsub(/"/, "", $2 );print $2}' )
	JBOSS_PATH_FULL=${JBOSS_ROOT}/${LITP_COMPONENT_NAME}_${ui_instance}_jee_instance
	CURL_COMMAND="${CURL} -s -H ${CURL_HEADER} http://${UI_INSTANCE_IP_ADDRESS}:8080/rest/apps/citrix/${CITRIX_APP_PATTERN}.ica"
	TOKEN=$( ${CURL_COMMAND} | ${GREP} -o ClearPassword=[0-9][0-9]*\-.*$ )

	#[ -z "${TOKEN}" ] && graceful_exit 1 "No token retrieved from UI JBoss instance UI_${ui_instance}_jee_instance"
	[ -z "${TOKEN}" ] && LITP_SU_ERROR_LIST=" ${LITP_SU_ERROR_LIST} ${ui_instance}" || LITP_SU_SUCCESS_LIST=" ${LITP_SU_SUCCESS_LIST} ${ui_instance}"

	#graceful_exit 0 "Token retrieved from UI JBoss instance UI_${ui_instance}_jee_instance"
done

if [ ! -z "${LITP_SU_ERROR_LIST}" ]; then
	graceful_exit 1 "No SSO security token received from these JBoss UI instances on node ${NODE_NAME}: ${LITP_SU_ERROR_LIST}"
else
	graceful_exit 0 "SSO security token received from all UI JBoss instances on node ${NODE_NAME}: ${LITP_SU_SUCCESS_LIST}"
fi