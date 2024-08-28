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
## LITP post_start hook script for SSO - this will be run as user "litp_jboss"
## as part of the LITP "deployable entity" definition

##############
# Command vars
##############
GREP=/bin/grep
SED=/bin/sed
ECHO=/bin/echo
AWK=/bin/awk
GLOBAL_PROPERTIES=/ericsson/tor/data/global.properties
LOCAL_PROPERTIES=/opt/ericsson/sso/etc/env-vars.conf

##
## Failure codes
##
INSTALLATION_EXISTS=10
SANITY_CHECK_FAILED=5
INSTALLATION_FAILED=1
NOW=`date +"%d-%m-%Y-%H%M"` 


##
## INFORMATION print
##
SCRIPT_NAME=`basename $0`
info()
{
	logger -s -t TOR_SSO -p user.notice "INFORMATION ( $SCRIPT_NAME ): $@"
}

error()
{
	logger -s -t TOR_SSO -p user.err "ERROR ( ${SCRIPT_NAME} ): $@"
}

##############
# FEATURE ENV
##############
if [ ! -f "${LOCAL_PROPERTIES}" ]; then
	error "File ${LOCAL_PROPERTIES} does not exist. Script cannot continue. Possible problem with RPM installation. Exiting"
	exit 0
fi
. ${LOCAL_PROPERTIES}

##
## Log messages
##
FAILURE_MESSAGE_ENV="Sanity check for environment failed. SSO installation cannot continue. Check all the values in the global poperties file."
FAILURE_MESSAGE_ENV="${FAILURE_MESSAGE_ENV} ${GLOBAL_PROPERTIES} are present and correct before running the campaign again."
FAILURE_MESSAGE_INSTALL="SSO initialisation failed, check /var/log/messages for entries tagged with ${SSO_SCRIPT} for possible reasons."
FAILURE_MESSAGE_INSTALL="${FAILURE_MESSAGE_INSTALL} The system may be in an unstable condition and the campaign cannot continue. Ensure the"
FAILURE_MESSAGE_INSTALL="${FAILURE_MESSAGE_INSTALL} directory ${SSO_FULL_SYMLINK} is empty before running the campaign again."
FAILURE_MESSAGE_INSTALL_EXTRA=" All relevant logs have been copied to /var/log/sso/install-${NOW}/ to inspect for failure reasons"
info "Calling SSO initialisation and configuration procedure"


get_logs()
{
	## Store all available logs to /var/log/sso/install-${NOW}
	mkdir -p /var/log/sso/install-${NOW} > /dev/null 2>&1
	for file in /tmp/{opends-*.log,opendj-*.log} /opt/ericsson/sso/heimdallr/install.log /opt/ericsson/sso/heimdallr/opends/logs/* /opt/ericsson/sso/heimdallr/heimdallr/debug/* /var/log/jboss/SSO_su_0_jee_instance/server.log
	do
		cp $file /var/log/sso/install-${NOW}/
	done

	# Check our temporary directory
	#  ${FAILURE_MESSAGE_INSTALL}="${FAILURE_MESSAGE_INSTALL} ${FAILURE_MESSAGE_INSTALL_EXTRA}"
	$( ls -A  /var/log/sso/install-${NOW} ) && return 0 || return 1
}


info "Calling SSO initialisation and configuration procedure"
${SSO_SCRIPT} init
ret_val=${?}
if [ ${ret_val} -eq ${INSTALLATION_EXISTS} ]; then
	info "SSO installation already exists, running upgrade procedure"
elif [ ${ret_val} -eq ${INSTALLATION_FAILED} ]; then
	get_logs && FAILURE_MESSAGE_INSTALL="${FAILURE_MESSAGE_INSTALL} ${FAILURE_MESSAGE_INSTALL_EXTRA}"
	error "${FAILURE_MESSAGE_INSTALL}"
	exit 1
elif [ ${ret_val} -eq ${SANITY_CHECK_FAILED} ]; then
	error "${FAILURE_MESSAGE_ENV}"
	exit 1
fi

info "SSO initialisation and configuration successful. Calling upgrade procedure"

${SSO_SCRIPT} upgrade
ret_val=${?}
if [ ${ret_val} -ne 0 ]; then
	error "Upgrade unsuccessful, campaign cannot continue"
	exit 1
fi

info "Upgrade complete, SSO install/upgrade successful"
exit 0
