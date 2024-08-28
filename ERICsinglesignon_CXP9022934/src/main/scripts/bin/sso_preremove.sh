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
## RPM %preun scriptlet

##############
# Command vars
##############
GREP=/bin/grep
SED=/bin/sed
ECHO="echo -e"
AWK=/bin/awk
SCRIPT_NAME=`basename $0`

##
## INFORMATION print
##
info()
{
	logger -s -t TOR_SSO -p user.err "INFORMATION ( $SCRIPT_NAME ): $@"
}

error()
{
	logger -s -t TOR_SSO -p user.err "ERROR ( ${SCRIPT_NAME} ): $@"
}

##############
# FEATURE ENV
##############
LOCAL_PROPERTIES=/opt/ericsson/sso/etc/env-vars.conf

if [ ! -f "${LOCAL_PROPERTIES}" ]; then
	info "File ${LOCAL_PROPERTIES} does not exist. Script cannot continue. Possible problem with RPM installation. Exiting"
	exit 1
fi
. ${LOCAL_PROPERTIES}

NOW=`date "+%F-%H%M%S"`
HST=`hostname`
label="before-uninstall-${HST}-${NOW}"

${SSO_BIN_DIR}/sso.sh status
ret_val=$?

#[ -x $SSO_HOME/bin/backup.sh -a -x ${SSO_SSOADM_HOME}/${SSO_DEPLOYMENT_NAME}/bin/ssoadm ] \
[ -x $SSO_HOME/bin/backup.sh -a ${ret_val} -eq 0 ] \
	&& ( info "Creating SSO config backup with label ${label}"; $SSO_HOME/bin/backup.sh create ${label} ) \
	|| info "Backup script not present or SSO not running. Skipping config backup step"

exit 0