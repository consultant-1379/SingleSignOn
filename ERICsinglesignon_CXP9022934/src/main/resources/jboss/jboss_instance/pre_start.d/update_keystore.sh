#!/bin/bash

##
## Update cert logic:
##
##	-	if any of the cert/key files are missing, do nothing: assume previous certs are still being used
##	-	if all files are present, check the SHA1 fingerprints of both the keystore entry and the .crt file
##		-	if the fingerprints differ, check the cert and key match
##          - if they match then export them to new keystores and imprt these into the main trust store
##


##
## COMMANDS
##
AWK=/bin/awk
BASENAME=/bin/basename
DIFF=/usr/bin/diff
ECHO="echo -e"
GREP=/bin/grep
LOGGER=/usr/bin/logger
KEYTOOL="sudo /usr/java/default/bin/keytool"
OPENSSL=/usr/bin/openssl
RM=/bin/rm
WC=/usr/bin/wc
UNIQ=/usr/bin/uniq

##
## PATHS
##
CERTS_LOCATION=/ericsson/tor/data/certificates/sso
#KEYSTORE=${CERTS_LOCATION}/sso-truststore.jks
KEYSTORE=/usr/java/default/jre/lib/security/cacerts
TEMP_KEYSTORE_LOCATION=/tmp

##
## ENVIRONMENT
##
APACHE_SERVER_CERT_ALIAS="apache-server"
APACHE_SERVER_CERT_FILE=${CERTS_LOCATION}/ssoserverapache.crt
APACHE_SERVER_KEYFILE=${CERTS_LOCATION}/ssoserverapache.key
APACHE_SERVER_KEYSTORE_FILE=${TEMP_KEYSTORE_LOCATION}/ssoserverapache.p12
COM_INF_CERT_ALIAS="sso"
FILESYSTEM_CERT_FINGERPRINT=${TEMP_KEYSTORE_LOCATION}/fs_cert_fingerprint
HTTPS_CONNECTOR_FOUND=""
JBOSS_SERVER_CERT_ALIAS="sso-server"
JBOSS_SERVER_CERT_FILE=${CERTS_LOCATION}/ssoserverjboss.crt
JBOSS_SERVER_KEYFILE=${CERTS_LOCATION}/ssoserverjboss.key
JBOSS_SERVER_KEYSTORE_FILE=${TEMP_KEYSTORE_LOCATION}/ssoserverjboss.p12
KEY_PASS="changeit"
KEYSTORE_CERT_FINGERPRINT=${TEMP_KEYSTORE_LOCATION}/keystore_cert_fingerprint
LOGGER_TAG="TOR_SSO"
ROOT_CA="${CERTS_LOCATION}/rootca.cer"
SCRIPT_NAME=$( ${BASENAME} ${0} )
SSO_CONTAINER_PATTERN="SSO"
container_check=$( ${ECHO} ${LITP_JEE_CONTAINER_instance_name} | ${GREP} ${SSO_CONTAINER_PATTERN} )
container_check_result=${?}

##
## ENVIRONMENT CHECK
##
FILES_TO_CHECK="${APACHE_SERVER_CERT_FILE} ${APACHE_SERVER_KEYFILE} ${JBOSS_SERVER_CERT_FILE} ${JBOSS_SERVER_KEYFILE}"

## CLEANUP
##
FILES_TO_REMOVE="${APACHE_SERVER_KEYSTORE_FILE} ${JBOSS_SERVER_KEYSTORE_FILE} ${KEYSTORE_CERT_FINGERPRINT} ${FILESYSTEM_CERT_FINGERPRINT}"

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
## Export x509 certificate and private key to a PKCS12 format keystore
##
## args: $1 - certificate file path
##       $2 - private key file path
##       $3 - exported temporary keystore
##       $4 - certificate alias for keystore
##
export_to_keystore()
{
	${OPENSSL} pkcs12 -export \
		-in ${1} \
		-name ${4} \
		-inkey ${2} \
		-passout pass:${KEY_PASS} \
		-out ${3} && info "${1} and ${2} exported to ${3}" || (info "Problem encounted while exporting ${1} and ${2} to keystore at ${3}. Exiting"; return 1 )
}

##
## Search keystore for an alias and delete the cert if it exists
##
## args: ${1} - alias to search for
##
search_keystore_and_delete()
{
	info "Searching for certificate with alias ${1} in ${KEYSTORE}"
	${KEYTOOL} -list -alias ${1} -keystore ${KEYSTORE} -storepass ${KEY_PASS} > /dev/null 2>&1
	if [ $? -eq 0 ]; then
		info "Certificate with alias ${1} already exists in ${KEYSTORE}. Deleting from keystore"
		${KEYTOOL} -delete -alias ${1} -keystore ${KEYSTORE} -storepass ${KEY_PASS} > /dev/null 2>&1
		[ ${?} -eq 0 ] && info "Certificate with alias ${1} successfully removed from ${KEYSTORE}" \
		|| ( warn "Could not delete existing certificate with alias ${1} from ${KEYSTORE}."; return 1 )
	else
		info "No certificate with alias ${1} exists in ${KEYSTORE} yet"
	fi

	return 0
}

##
## Replace root CA using keytool
##
## args: $1 - certificate alias
##       $2 - root CA file name
update_root_ca()
{
	info "Importing new certificate from ${2} with alias ${1} into ${KEYSTORE}"
	${KEYTOOL} \
		-import \
		-alias ${1} \
		-keystore ${KEYSTORE} \
		-storepass ${KEY_PASS} \
		-file ${2} \
		-noprompt \
		-trustcacerts > /dev/null 2>&1 \
	&& info "Certificate at ${2} with alias ${1} imported successfully" \
	|| ( info "Could not import new certificate at ${2} with alias ${1}. Will use existing configuration"; return 1 )

	return 0
}

##
## Replace certificates using keytool (different keystore types needed)
##
## args: $1 - temporary keystore
##
update_server_cert()
{
	info "Importing new keystore from ${1} into ${KEYSTORE}"
	${KEYTOOL} -importkeystore \
		-srckeystore ${1} \
		-destkeystore ${KEYSTORE} \
		-srcstorepass ${KEY_PASS} \
		-deststorepass ${KEY_PASS} \
		-srcstoretype PKCS12 \
		-deststoretype JKS \
	&& info "Keystore at ${1} imported successfully" \
	|| ( warn "Could not import new keystore at ${1} into ${KEYSTORE}"; return 1 )
}

##
## Check that a certificate and private key pair match
##
## args: $1 - certificate file path
##       $2 - private key file path
##
check_certificate_and_key_match()
{
	info "Checking certificate ${1} against key ${2}"

	MATCH=$( ( ${OPENSSL} x509 -noout -modulus -in ${1} | ${OPENSSL} md5; \
	${OPENSSL} rsa -noout -modulus -in ${2} | ${OPENSSL} md5 ) | ${UNIQ} | ${WC} -l ) 

	[ ${MATCH} -eq 1 ] && return 0 || return 1
}

##
## Export the SHA1 fingerprints of the certificate in the keystore
## and the certificate on the filesystem to temporary files, then
## compare the two files
##
## args: $1 - keystore alias
##       $2 - certificate on the filesystem
##
check_certificate_fingerprints()
{
	if [ ! -f ${KEYSTORE} ]; then
		info "No existing keystore at ${KEYSTORE}, one will be created"
		return 1
	fi

	## 
	## Handle a fresh install - no SSO aliases will exist yet
	##
	${KEYTOOL} -list -alias ${1} -keystore ${KEYSTORE} -storepass ${KEY_PASS} > /dev/null 2>&1
	if [ $? -ne 0 ]; then
		info "No certificate with alias ${1} exists in ${KEYSTORE}, importing now"
		return 1
	fi

	info "Checking if certificates need to be updated"

	# Dump keystore finger print to a file
	${KEYTOOL} -list\
		-keystore ${KEYSTORE}\
		-storepass ${KEY_PASS}\
		-alias ${1} | ${AWK} -v tmp_alias=${1} '$0 ~ tmp_alias {next};{print $4}' > ${KEYSTORE_CERT_FINGERPRINT}

	# Dump filesystem cert fingerprint to a file
	${OPENSSL} x509 \
		-in ${2} \
		-fingerprint \
		-noout | ${AWK} -F '=' '{print $2}' > ${FILESYSTEM_CERT_FINGERPRINT}

	# Compare the two files
	${DIFF} ${KEYSTORE_CERT_FINGERPRINT} ${FILESYSTEM_CERT_FINGERPRINT} && return 0 || return 1
}

##
## Check all necessary files for execution exist,
## exit with error if otherwise
##
check_files_exist()
{
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
[ ${container_check_result} -ne 0 ] && graceful_exit 0 "This is not the SSO container, skipping script execution" \
|| info "SSO Container found, executing script"

##
## APACHE
##
if [ -f ${APACHE_SERVER_CERT_FILE} -a -f ${APACHE_SERVER_KEYFILE} ] ; then

	# Check Apache server certificate fingerprints
	check_certificate_fingerprints ${APACHE_SERVER_CERT_ALIAS} ${APACHE_SERVER_CERT_FILE}
	if [ ${?} -ne 0 ]; then

		# Certificate fingerprints differ, so check if we can update the certificate
		check_certificate_and_key_match ${APACHE_SERVER_CERT_FILE} ${APACHE_SERVER_KEYFILE}
		if [ ${?} -eq 0 ]; then

			info "Key ${APACHE_SERVER_KEYFILE} matches certificate ${APACHE_SERVER_CERT_FILE}, exporting to temporary keystore"
			export_to_keystore ${APACHE_SERVER_CERT_FILE} ${APACHE_SERVER_KEYFILE} ${APACHE_SERVER_KEYSTORE_FILE} ${APACHE_SERVER_CERT_ALIAS}
			if [ ${?} -eq 0 ]; then

				info "Temporary keystore created, importing to main trust store"
				
				TEMP_VAL=0
				if [ -f ${KEYSTORE} ]; then
					search_keystore_and_delete ${APACHE_SERVER_CERT_ALIAS} || TEMP_VAL=1
				else
					info "Trust store at ${KEYSTORE} does not exist, one will be created"
				fi

				if [ ${TEMP_VAL} -eq 0 ]; then

					info "Updating trust store with new certificate with alias ${APACHE_SERVER_CERT_ALIAS}"
					update_server_cert ${APACHE_SERVER_KEYSTORE_FILE} \
					&& info "Certificate at ${APACHE_SERVER_CERT_FILE} successfully updated in JBoss trust store." \
					|| warn "Could not update certificate at ${APACHE_SERVER_CERT_FILE}, existing certificate will be used instead"
				else
					warn "Could not delete certificate with alias ${APACHE_SERVER_CERT_ALIAS} from keystore."
					warn "Will use existing configuration instead"
				fi

			else
				warn "Could not export certificate at ${APACHE_SERVER_CERT_FILE} for updating, existing certificate will be used instead"
			fi

		else
			warn "Key ${APACHE_SERVER_KEYFILE} does not match certificate ${APACHE_SERVER_CERT_FILE}."
			warn "Cannot update this certificate. Existing certificate will be used instead"
		fi

	else
		info "No new certificate at ${APACHE_SERVER_CERT_FILE} to update"
	fi
else
	info "Required files ${APACHE_SERVER_CERT_FILE} and ${APACHE_SERVER_KEYFILE} are not present"
	info "Cannot update certificates. Existing certificate will be used instead"
fi


##
## JBoss
##
if [ -f ${JBOSS_SERVER_CERT_FILE} -a -f ${JBOSS_SERVER_KEYFILE} ] ; then

	# Check JBoss server certificate fingerprints
	check_certificate_fingerprints ${JBOSS_SERVER_CERT_ALIAS} ${JBOSS_SERVER_CERT_FILE}
	if [ ${?} -ne 0 ]; then

		# Certificate fingerprints differ, so check if we can update the certificate
		check_certificate_and_key_match ${JBOSS_SERVER_CERT_FILE} ${JBOSS_SERVER_KEYFILE}
		if [ ${?} -eq 0 ]; then

			info "Key ${JBOSS_SERVER_KEYFILE} matches certificate ${JBOSS_SERVER_CERT_FILE}, exporting to temporary keystore"
			export_to_keystore ${JBOSS_SERVER_CERT_FILE} ${JBOSS_SERVER_KEYFILE} ${JBOSS_SERVER_KEYSTORE_FILE} ${JBOSS_SERVER_CERT_ALIAS}
			if [ ${?} -eq 0 ]; then

				info "Temporary keystore created, importing to main trust store"
				
				TEMP_VAL=0
				if [ -f ${KEYSTORE} ]; then
					search_keystore_and_delete ${JBOSS_SERVER_CERT_ALIAS} || TEMP_VAL=1
				else
					info "Trust store at ${KEYSTORE} does not exist, one will be created"
				fi

				if [ ${TEMP_VAL} -eq 0 ]; then

					info "Updating trust store with new certificate with alias ${JBOSS_SERVER_CERT_ALIAS}"
					update_server_cert ${JBOSS_SERVER_KEYSTORE_FILE} \
					&& info "Certificate at ${JBOSS_SERVER_CERT_FILE} successfully updated in JBoss trust store." \
					|| warn "Could not update certificate at ${JBOSS_SERVER_CERT_FILE}, existing certificate will be used instead"
				else
					warn "Could not delete certificate with alias ${JBOSS_SERVER_CERT_ALIAS} from keystore."
					warn "Will use existing configuration instead"
				fi

			else
				warn "Could not export certificate at ${JBOSS_SERVER_CERT_FILE} for updating, existing certificate will be used instead"
			fi

		else
			warn "Key ${JBOSS_SERVER_KEYFILE} does not match certificate ${JBOSS_SERVER_CERT_FILE}."
			warn "Cannot update this certificate. Existing certificate will be used instead"
		fi

	else
		info "No new certificate at ${JBOSS_SERVER_CERT_FILE} to update"
	fi
else
	info "Required files ${JBOSS_SERVER_CERT_FILE} and ${JBOSS_SERVER_KEYFILE} are not present"
	info "Cannot update certificates. Existing certificate will be used instead"
fi


# Special case for the root ca
if [ -f ${ROOT_CA} ]; then

	check_certificate_fingerprints ${COM_INF_CERT_ALIAS} ${ROOT_CA}
	if [ ${?} -ne 0 ]; then

		# Certificate fingerprints differ, update the root CA
		TEMP_VAL=0
		if [ -f ${KEYSTORE} ]; then
			search_keystore_and_delete ${COM_INF_CERT_ALIAS} ${ROOT_CA} || TEMP_VAL=1
		else
			info "Trust store at ${KEYSTORE} does not exist, one will be created"
		fi

		if [ ${TEMP_VAL} -eq 0 ]; then
			info "Updating trust store with new certificate with alias ${COM_INF_CERT_ALIAS}"
			update_root_ca ${COM_INF_CERT_ALIAS} ${ROOT_CA} \
		else
			warn "Could not delete certificate with alias ${COM_INF_CERT_ALIAS} from keystore."
			warn "Will use existing configuration instead"
		fi

	else
		info "No new certificate at ${ROOT_CA} to update"
	fi
else
	info "Required file ${ROOT_CA} not present, using existing root CA configuration"
fi

graceful_exit 0