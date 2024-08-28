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
## Sanity check script called when SSO install or upgrade operation is performed on the node.

##############
# Command vars
##############
GREP=/bin/grep
SED=/bin/sed
ECHO="echo -e"
AWK=/bin/awk
CURL=/usr/bin/curl
GETENT=/usr/bin/getent
GLOBAL_PROPERTIES=/ericsson/tor/data/global.properties
LOCAL_PROPERTIES=/opt/ericsson/sso/etc/env-vars.conf
SCRIPT_NAME=`basename $0`
SSO_COOKIE_DOMAIN=`domainname`
KEYTOOL=/usr/java/default/bin/keytool
KEYSTORE=/usr/java/default/jre/lib/security/cacerts
ROOTCA_CERT=/var/tmp/rootca.cer
CURL_COMMAND=""
CERTIFCATE_ALIAS_LIST="sso sso-server apache-server"

##
## INFORMATION print
##
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

if [ ! -f "$GLOBAL_PROPERTIES" ]; then
	error "File $GLOBAL_PROPERTIES does not exist. Please create it with appropriate values before running this script again. See /opt/ericsson/sso/etc/global-properties.template for an example"
	exit 1
fi

if [ ! -f "${LOCAL_PROPERTIES}" ]; then
	error "File ${LOCAL_PROPERTIES} does not exist. Script cannot continue. Possible problem with RPM installation. Exiting"
	exit 1
fi

. ${GLOBAL_PROPERTIES}
. ${LOCAL_PROPERTIES}

##
## Location for temporary certificate for checking LDAPS
##
TMP_CERT=${SSO_CONFIG_HOME}/${SSO_NAME}/tmp.cer

#############
# FUNCTIONS #
#############
attempt_to_ping_host()
{
	# Send two packets
	info "Attempting to reach ${1}"
	if ping -c 2 ${1} > /dev/null 2>&1; then
		info "${1} is reachable."
	else
		error "${1} is not reachable. Please check the /etc/hosts alias matches the correct IP address, or network connectivity to IP address"
		exit 1
	fi
}

check_keystore_for_alias()
{
	info "Searching for certificate with alias ${1} in ${KEYSTORE}"
	${KEYTOOL} -list -alias ${1} -keystore ${KEYSTORE} -storepass changeit > /dev/null 2>&1
	if [ $? -ne 0 ]; then
		error "Certificate with alias ${1} does not exist in ${KEYSTORE}. Please import an appropiate certificate"
		exit 1
	fi
	info "Certificate with alias ${1} found"
}

check_ldap_connectivity()
{
	CURL_COMMAND="${CURL} --cacert ${2} ldaps://${1}/${COM_INF_LDAP_ROOT_SUFFIX} > /dev/null 2>&1"
	eval ${CURL_COMMAND}
	ret_val=${?}

	case ${ret_val} in
		39)		error "LDAP: Unable to bind to ${1} with root suffix ${COM_INF_LDAP_ROOT_SUFFIX}. Check this value is correct"
				return 1
				;;
				
		38)		error "LDAP: Unable to bind to ${1} with certificate file ${2}"
				return 1
				;;
				
		7)		error "LDAP: Unable to connect to ${1}. Possible problem with LDAP port number being used or firewall"
				return 1
				;;
				
		6)		error "LDAP: Unable to connect to ${1}. Possible problem with the IP address or DNS name being used. Check /etc/hosts"
				return 1
				;;
				
		0)		info "LDAP: Connectivity to ${1} established. Continuing"
				return 0
				;;
				
		*)		error "LDAP: Unkown LDAP exception occurred. Error code was ${ret_val}"
				return 1
				;;
	esac				
}

info "Beginning sanity check"
# Test if any of the variables are empty

# 1. UI_PRES_SERVER
if [ -z "$UI_PRES_SERVER" ]; then
	error "UI_PRES_SERVER variable is empty. Please set it before running script again. Exiting"
	exit 1
fi
info "UI_PRES_SERVER set to: $UI_PRES_SERVER"

# 2. Cookie Domain
# if [ -z "$SSO_COOKIE_DOMAIN" ]; then
# 	SSO_COOKIE_DOMAIN=`domainname`
# 	if [[ -z "$SSO_COOKIE_DOMAIN" || "$SSO_COOKIE_DOMAIN" = "(none)" ]]; then
# 		error "SSO_COOKIE_DOMAIN variable is empty. Please set it before running script again. Exiting"
# 		exit 1
# 	fi
# fi
# info "SSO_COOKIE_DOMAIN set to: $SSO_COOKIE_DOMAIN"
# $ECHO "SSO_COOKIE_DOMAIN=${SSO_COOKIE_DOMAIN}" >> ${LOCAL_PROPERTIES}

# 2. Cookie Domain
if [ -z "$SSO_COOKIE_DOMAIN" ]; then
	error "SSO_COOKIE_DOMAIN variable is empty. Please set it before running script again. Exiting"
	exit 1
fi
info "SSO_COOKIE_DOMAIN set to: $SSO_COOKIE_DOMAIN"

# 3. LDAP host 1
#COM_INF_LDAP_HOST_1=`$GETENT hosts ldap1 | $AWK -F' ' '{print $1}'` 
if [ -z "$COM_INF_LDAP_HOST_1" ]; then
	error "COM_INF_LDAP_HOST_1 variable is empty. Please set it before running script again. Exiting"
	exit 1
fi
info "COM_INF_LDAP_HOST_1 set to: $COM_INF_LDAP_HOST_1"
#${ECHO} "COM_INF_LDAP_HOST_1=${COM_INF_LDAP_HOST_1}" >> ${LOCAL_PROPERTIES}

# 4. LDAP host 2
#COM_INF_LDAP_HOST_2=`$GETENT hosts ldap2 | $AWK -F' ' '{print $1}'`
if [ -z "$COM_INF_LDAP_HOST_2" ]; then
	error "COM_INF_LDAP_HOST_2 variable is empty. Please set it before running script again. Exiting"
	exit 1
fi
info "COM_INF_LDAP_HOST_2 set to: $COM_INF_LDAP_HOST_2"
#${ECHO} "COM_INF_LDAP_HOST_2=${COM_INF_LDAP_HOST_2}" >> ${LOCAL_PROPERTIES}

# 5. LDAP port
if [ -z "$COM_INF_LDAP_PORT" ]; then
	error "COM_INF_LDAP_PORT variable is empty. Please set it before running script again. Exiting"
	exit 1
fi
info "COM_INF_LDAP_PORT set to: $COM_INF_LDAP_PORT"

# 6. LDAP Root Suffix
if [ -z "$COM_INF_LDAP_ROOT_SUFFIX" ]; then
	error "COM_INF_LDAP_ROOT_SUFFIX variable is empty. Please set it before running script again. Exiting"
	exit 1
fi
info "COM_INF_LDAP_ROOT_SUFFIX set to: $COM_INF_LDAP_ROOT_SUFFIX"

# 7. LDAP admin Common Name (cn)
if [ -z "$COM_INF_LDAP_ADMIN_CN" ]; then
	error "COM_INF_LDAP_ADMIN_CN variable is empty. Please set it before running script again. Exiting"
	exit 1
fi
info "COM_INF_LDAP_ADMIN_CN set to: $COM_INF_LDAP_ADMIN_CN"

# 8. LDAP password
if [ -z "$COM_INF_LDAP_ADMIN_ACCESS" ]; then
	error "COM_INF_LDAP_ADMIN_ACCESS variable is empty. Please set it before running script again. Exiting"
	exit 1
fi
info "COM_INF_LDAP_ADMIN_ACCESS set to: ****"

# Attempt to reach all servers needed
for server in ${AM_SERVER} ${COM_INF_LDAP_HOST_1} ${COM_INF_LDAP_HOST_2}; do
	attempt_to_ping_host ${server}
done

# Check default keystore for approppiate aliases
for alias in ${CERTIFCATE_ALIAS_LIST}; do
	check_keystore_for_alias ${alias}
done

# Check both hosts on port 636
( nc -z $COM_INF_LDAP_HOST_1 389 -w 1 > /dev/null 2>&1 && nc -z $COM_INF_LDAP_HOST_1 ${COM_INF_LDAP_PORT} -w 1 > /dev/null 2>&1 ) || \
( nc -z $COM_INF_LDAP_HOST_2 389 -w 1 > /dev/null 2>&1 && nc -z $COM_INF_LDAP_HOST_2 ${COM_INF_LDAP_PORT} -w 1 > /dev/null 2>&1 )
ldap_ret_val=${?}
if [ ${ldap_ret_val} -ne 0 ]; then
	FAILURE_MESSAGE="Cant make connection to either LDAP host on ports 389 and 636. Problem"
	FAILURE_MESSAGE=" ${FAILURE_MESSAGE} either with firewall or remote servers, or LDAP server is"
	FAILURE_MESSAGE=" ${FAILURE_MESSAGE} is in an unknown state. Installation of SSO cannot continue."
	FAILURE_MESSAGE=" ${FAILURE_MESSAGE} Once the issue has been resolved, run '${SSO_BIN_DIR}/sso.sh init'"
	FAILURE_MESSAGE=" ${FAILURE_MESSAGE} or restart the SSO JBoss container to install SSO"
	error ${FAILURE_MESSAGE}
	exit 1
fi

info "Exporting certificate in PEM format to test secure LDAP connectivity"
${KEYTOOL} -export -keystore ${KEYSTORE} -storepass changeit -alias sso -rfc -file ${TMP_CERT} > /dev/null 2>&1
if [ ! -f "${TMP_CERT}" ]; then
	error "Could not export certificate, can the current user write to the directory where ${TMP_CERT} should be? Exiting sanity check"
	exit 1
fi
info "Certificate successfully exported to ${TMP_CERT}"

if grep "BEGIN CERTIFICATE" ${TMP_CERT} > /dev/null 2>&1; then
	info "Certificate is in PEM format, continuing with LDAPS check"
else
	error "Certificate is not in PEM format, exiting sanity check"
	exit 1
fi

info "Testing secure LDAP connectivity to ${COM_INF_LDAP_HOST_1}"
check_ldap_connectivity ${COM_INF_LDAP_HOST_1} ${TMP_CERT}
if [ $? -ne 0 ]; then
	error "Problem occured with secure LDAP connectivity to ${COM_INF_LDAP_HOST_1}. Checking ${COM_INF_LDAP_HOST_1}"
	check_ldap_connectivity ${COM_INF_LDAP_HOST_2} ${TMP_CERT}
	if [ $? -ne 0 ]; then
		error "Can't contact either LDAP host. Cannot continue. Check certificate, host and root suffix values"
		info "Removing temporary cert"
		rm -f ${TMP_CERT}
		exit 1
	fi
fi
info "Secure connection to LDAP confirmed"

if [ -f ${TMP_CERT} ]; then
	info "Removing temporary cert"
	rm -f ${TMP_CERT}
fi


info "LDAP configuration appears ok"
info "Sanity check passed."

exit 0
