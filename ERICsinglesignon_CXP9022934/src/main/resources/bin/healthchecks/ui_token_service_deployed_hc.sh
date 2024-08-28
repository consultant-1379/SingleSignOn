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
## Script to check whether the "Security Service" EAR file is deployed
## in all UI JBoss instances running on this node
##
## returns: 0 if EAR file is fully deployed
##          1 if EAR file is NOT fully deployed

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
DEPLOY_TEST=""
DEPLOY_ERROR_LIST=""
DEPLOY_SUCCESS_LIST=""
JBOSS_ROOT=/home/jboss
EAR_SEARCH_PATTERN="SecurityService"
EAR_SEARCH_ERROR_LIST=""
EAR_SEARCH_SUCCESS_LIST=""
JBOSS_CLI=""
JBOSS_COMMAND="--command='deploy -l'"
JBOSS_PATH_FULL=""
JBOSS_OUTPUT=""
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
		#remove_file ${i}
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
	JBOSS_CLI="${JBOSS_ROOT}/${LITP_COMPONENT_NAME}_${ui_instance}_jee_instance/bin/jboss-cli.sh --controller=${UI_INSTANCE_IP_ADDRESS} -c --command=\"deploy -l\""
	JBOSS_OUTPUT=$( eval ${JBOSS_CLI} | ${GREP} ${EAR_SEARCH_PATTERN} )

	#[ -z "${JBOSS_OUTPUT}" ] && graceful_exit 1 "${EAR_SEARCH_PATTERN} EAR is not deployed in JBoss instance ${JBOSS_PATH_FULL}"
	[ -z "${JBOSS_OUTPUT}" ] && EAR_SEARCH_ERROR_LIST="${EAR_SEARCH_ERROR_LIST} ${ui_instance} " || EAR_SEARCH_SUCCESS_LIST="${EAR_SEARCH_SUCCESS_LIST} ${ui_instance} "

	DEPLOY_TEST=$( ${ECHO} ${JBOSS_OUTPUT} | ${AWK} '/true/ && /OK/' )

	#[ -z "${DEPLOY_TEST}" ] && graceful_exit 1 "${EAR_SEARCH_PATTERN} EAR is deployed but not enabled in JBoss instance ${JBOSS_PATH_FULL}"
	[ -z "${DEPLOY_TEST}" ] && DEPLOY_ERROR_LIST="${DEPLOY_ERROR_LIST} ${ui_instance} " || DEPLOY_SUCCESS_LIST="${DEPLOY_SUCCESS_LIST} ${ui_instance} "

done

if [ ! -z "${EAR_SEARCH_ERROR_LIST}" ]; then
	graceful_exit 1 "${EAR_SEARCH_PATTERN} EAR is not deployed on these UI JBoss instances on node ${NODE_NAME}: ${EAR_SEARCH_ERROR_LIST}"
fi

if [ ! -z "${DEPLOY_ERROR_LIST}" -a -z "${EAR_SEARCH_ERROR_LIST}" ]; then
	graceful_exit 1 "${EAR_SEARCH_PATTERN} EAR is not enabled on these UI JBoss instances on node ${NODE_NAME}: ${DEPLOY_ERROR_LIST}"
fi

graceful_exit 0 "${EAR_SEARCH_PATTERN} EAR is fully deployed and enabled on these UI JBoss instances in ${NODE_NAME}: ${DEPLOY_SUCCESS_LIST}"