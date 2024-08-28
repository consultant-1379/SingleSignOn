#
# Files in this folder with '.conf' extension will be read
# and executed as a batch update to the Single Sign On server
#
# e.g.
#
# 	update-agent -e /${REALM_NAME} -b ${SSO_AGENT_NAME} -a '"com.sun.identity.agents.config.debug.level=Error"'
#
# Note the double quotes are surrounded by single quotes to avoid shell substitution and evaluation
#