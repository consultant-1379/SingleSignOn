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
## RPM %post scriptlet

#set -vx

##############
# Command vars
##############
GREP=/bin/grep
SED=/bin/sed
ECHO=/bin/echo
AWK=/bin/awk
MKDIR=/bin/mkdir
LN=/bin/ln
JAR=/usr/bin/jar

##
## INFORMATION print
##
prg=`basename $0`
info()
{
	logger -s -t TOR_SSO -p user.notice "INFORMATION ( $prg ): $@"
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
	exit 0
fi
. ${LOCAL_PROPERTIES}

#############
# FUNCTIONS #
#############
install_jre ()
{
	info "Installing JRE 1.6"
	cd $SSO_HOME
	./$JRE_SCRIPT_NAME > /dev/null 2>&1
	ln -s $JRE_VERSION/ jre > /dev/null 2>&1
	./jre/bin/java -version > /dev/null 2>&1 && info "JRE 1.6 installed"
	cd - >> /dev/null
}

setup_sso_home ()
{
	[ ! -d $SSO_CONFIG_HOME/$SSO_NAME -o ! -L ${SSO_HOME}/$SSO_NAME ] && setup_config_dir \
	|| info "$SSO_CONFIG_HOME/$SSO_NAME exists and is linked from ${SSO_HOME}/$SSO_NAME, skipping sso directory setup phase"
	info "Preparing SSO_HOME directory"
	chmod 400 ${SSO_HOME}/etc/*.bin
	chown $JBOSS_USER:$JBOSS_GROUP ${SSO_HOME}/etc/*.bin
	if [ ! -d /var/log/sso ]; then
		info "Preparing log directory /var/log/sso"
		mkdir -p /var/log/sso
		chown -R $JBOSS_USER:$JBOSS_GROUP /var/log/sso
	fi
}

setup_config_dir ()
{
	info "Creating $SSO_CONFIG_HOME/$SSO_NAME"
	${MKDIR} -p $SSO_CONFIG_HOME/$SSO_NAME
	cd $SSO_HOME
	${LN} -s $SSO_CONFIG_HOME/$SSO_NAME $SSO_NAME
	cd - >> /dev/null
	chown -R $JBOSS_USER:$JBOSS_GROUP $SSO_CONFIG_HOME/$SSO_NAME
}

prepare_tools ()
{
	[ ! -f ${SSO_CONFIGURATOR_HOME}/configurator.jar ] && setup_configurator_tools || info "SSO command line config tools already setup, skipping phase"
	[ ! -x ${SSO_SSOADM_HOME}/${SSO_DEPLOYMENT_NAME}/setup ] && setup_admin_tools || info "SSO command line admin tools already setup, skipping phase"
}

setup_configurator_tools ()
{
	info "Extracting OpenAM command-line configurator tools"
	cd $SSO_CONFIGURATOR_HOME
	${JAR} -xvf ../ssoConfiguratorTools.zip > /dev/null 2>&1
	cd - >> /dev/null
}

setup_admin_tools ()
{
	info "Extracting OpenAM command-line admin tools"
	cd ${SSO_SSOADM_HOME}
	${JAR} -xvf ../ssoAdminTools.zip > /dev/null 2>&1
	chmod +x $SSO_SSOADM_HOME/setup
	chown -R $JBOSS_USER:$JBOSS_USER .
	cd - >> /dev/null
}

set_ownership ()
{
	chown -R $JBOSS_USER:$JBOSS_USER ${1}
}

setup_env ()
{
	info "Setting up SSO environment"
	install_jre
	setup_sso_home
	prepare_tools
	info "SSO environment setup complete"
}

do_upgrade ()
{
	info "Upgrading SSO environment"
	chown -R $JBOSS_USER:$JBOSS_USER ${SSO_SSOADM_HOME}
	chmod 400 ${SSO_HOME}/etc/*.bin
	chown $JBOSS_USER:$JBOSS_GROUP ${SSO_HOME}/etc/*.bin
}

###########
# EXECUTION
###########
[ ${1} -eq 1 ] && setup_env

[ ${1} -eq 2 ] && do_upgrade
exit 0
