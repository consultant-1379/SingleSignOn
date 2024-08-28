#!/bin/bash

TARGET_DIR="/var/log/sso"
SYMLINK_FILE1="Link_amAuthentication.access"
SYMLINK_PATH1="$TARGET_DIR/$SYMLINK_FILE1"
SYMLINK_FILE2="Link_amSSO.access"
SYMLINK_PATH2="$TARGET_DIR/$SYMLINK_FILE2"
SYMLINK_FILE3="Link_amPolicy.access"
SYMLINK_PATH3="$TARGET_DIR/$SYMLINK_FILE3"
SYMLINK_FILE4="Link_amPolicyDelegation.access"
SYMLINK_PATH4="$TARGET_DIR/$SYMLINK_FILE4"
SYMLINK_FILE5="Link_entitlement.access"
SYMLINK_PATH5="$TARGET_DIR/$SYMLINK_FILE5"
SYMLINK_FILE6="Link_amAuthentication.error"
SYMLINK_PATH6="$TARGET_DIR/$SYMLINK_FILE6"
SYMLINK_FILE7="Link_amPolicy.error"
SYMLINK_PATH7="$TARGET_DIR/$SYMLINK_FILE7"

SCRIPT_LOCK_DIR=/tmp/sso_symlink_update.lock
SCRIPT_LOCK_PID_FILE=${SCRIPT_LOCK_DIR}/.sso_symlink_update_pid

ECHO="echo -e"
TAIL=/usr/bin/tail
AWK=/bin/awk
CAT=/bin/cat
GREP=/bin/grep
KILL=/bin/kill
MKDIR=/bin/mkdir
RM=/bin/rm
TOUCH=/bin/touch
LS=/bin/ls
LN=/bin/ln
SLEEP=/bin/sleep
SCRIPT_NAME=`basename $0`

info()
{
	logger -s -t TOR_SSO -p user.notice "INFORMATION ( ${SCRIPT_NAME} ): $@"
}



error()
{
	logger -s -t TOR_SSO -p user.err "ERROR ( ${SCRIPT_NAME} ): $@"
}

getLock() {
# Local vars local script_pid
# Check for safe SCRIPT_LOCK_DIR setting
if ! $ECHO "${SCRIPT_LOCK_DIR}" | ${GREP} "^/tmp/" >/dev/null; then
        error "Error: Invalid SCRIPT_LOCK_DIR setting: [${SCRIPT_LOCK_DIR}]. Lock directory must be created under /tmp\n"
        #exit 1
        exit 0
fi
if [ ! -d "${SCRIPT_LOCK_DIR}" ]; then
        $MKDIR -p ${SCRIPT_LOCK_DIR} 2> /dev/null
fi
# Lock FAILED - check for stale lockinfo " HC lock FAILED; checking for stale lock ..."
MY_SCRIPT_pid=($$)
$TOUCH ${SCRIPT_LOCK_PID_FILE}
SCRIPT_pid=`(${CAT} ${SCRIPT_LOCK_PID_FILE})`
info " Lock PID file contains: ${SCRIPT_pid}"
if [ -n "${SCRIPT_pid}" ]; then
         info "Current pid ${SCRIPT_pid} , my pid ${MY_SCRIPT_pid} "
         if [ "${MY_SCRIPT_pid}" ==  "${SCRIPT_pid}" ]; then
          $ECHO ${MY_SCRIPT_pid} > ${SCRIPT_LOCK_PID_FILE}
          info "I locked the file"
          LOCKED=0
         else
         # Wait a bit before assuming stale lock i.e. a script
         # was interrupted after acquiring the lock but before
         # it could install the interupt handler to remove it
         sleep 5
         fi


# Check for active process with discovered pid
         $KILL -0 ${SCRIPT_pid} 2> /dev/null
         if [ "${?}" = "0" ]; then
                # Another active process already has the lock
                error "Error: Another process with PID [${SCRIPT_pid}] has locked this admin function. Please try later.\n"
                LOCKED=1
                return 1
         else
                # Remove stale lock
                [ -d "${SCRIPT_LOCK_DIR}" ] && $CAT /dev/null > ${SCRIPT_LOCK_PID_FILE}
                info " Removed stale HC lock."
                $ECHO "${MY_SCRIPT_pid}" > ${SCRIPT_LOCK_PID_FILE}
                LOCKED=0
         fi
else
        info "My value set in current lock file, locking"
        $ECHO "${MY_SCRIPT_pid}" > ${SCRIPT_LOCK_PID_FILE}
        LOCKED=0
fi
# There is no active process with this pid - remove stale lock [ -d "${SCRIPT_LOCK_DIR}" ] && $RM -rf ${SCRIPT_LOCK_DIR} echo " No active process with PID [$SCRIPT_pid]; Removed stale HC lock."
# Try to lock again getHCLock
}

releaseLock() {
# Check for safe SCRIPT_LOCK_DIR setting
if ! $ECHO "${SCRIPT_LOCK_DIR}" | ${GREP} "^/tmp/" >/dev/null; then
        error "Error:  Invalid SCRIPT_LOCK_DIR setting: [${SCRIPT_LOCK_DIR}]. Lock directory must be created under /tmp\n"

        exit 0
fi
# Check lock exists
if [ ! -d "${SCRIPT_LOCK_DIR}" ]; then
       info " No lock to release."
        LOCKED=0
        return 0
fi
local SCRIPT_pid=$($CAT ${SCRIPT_LOCK_PID_FILE} 2>/dev/null)
if [ -z "${SCRIPT_pid}" ]; then
        # Wait a bit
        sleep 5
        local SCRIPT_pid=$(${CAT} ${SCRIPT_LOCK_PID_FILE} 2>/dev/null)
fi


# Decide lock is stale if still no pid
if [ -z "${SCRIPT_pid}" ]; then
        # Remove stale lock
        [ -d "${SCRIPT_LOCK_DIR}" ] && $RM -rf ${SCRIPT_LOCK_DIR}
       info " Removed stale HC lock."
        LOCKED=0
        return 0
fi
# Release only if this process has the lock
if [ "${SCRIPT_pid}" = "$$" ]; then
        # Release the lock
        [ -d "${SCRIPT_LOCK_DIR}" ] && $RM -rf ${SCRIPT_LOCK_DIR}
       info " Released HC lock [${SCRIPT_LOCK_DIR}]."
        LOCKED=0
	kill -9 $SCRIPT_pid
        return 0
fi
# Not locked by this processinfo " This process [$$] tried to release a HC lock but process [$SCRIPT_pid] is the lock owner."
LOCKED=1
return 1
}


function getLastModifiedFile {
    	$ECHO $($LS -t "$TARGET_DIR" | $GREP $1 | $GREP -v $2 | head -1)
}



function updateSymLinks {

	symlinkedFile_AmAuth=$SYMLINK_PATH1
	symlinkedFile_AmSSO=$SYMLINK_PATH2
	symlinkedFile_AmPolicy=$SYMLINK_PATH3
	symlinkedFile_AmPolicyDel=$SYMLINK_PATH4
	symlinkedFile_Entitlement=$SYMLINK_PATH5
	symlinkedFile_AmAuthError=$SYMLINK_PATH6
	symlinkedFile_AmPolicyErr=$SYMLINK_PATH7

	while true
	do
	
	$SLEEP 3 
    		lastModifiedFile_AmAuth=$(getLastModifiedFile amAuthentication.access $SYMLINK_FILE1 )			
    		if [[ $symlinkedFile_AmAuth != $lastModifiedFile_AmAuth ]]
    		then
        		$LN -nsf "$TARGET_DIR/$lastModifiedFile_AmAuth" $SYMLINK_PATH1
        		symlinkedFile_AmAuth=$lastModifiedFile_AmAuth
    		fi

    		lastModified_AmSSO=$(getLastModifiedFile amSSO.access $SYMLINK_FILE2)				
    		if [[ $symlinkedFile_AmSSO != $lastModified_AmSSO ]]
    		then
        		$LN -nsf "$TARGET_DIR/$lastModified_AmSSO" $SYMLINK_PATH2
        		symlinkedFile_AmSSO=$lastModified_AmSSO
    		fi

		lastModified_AmPolicy=$(getLastModifiedFile amPolicy.access $SYMLINK_FILE3)
                if [[ $symlinkedFile_AmPolicy != $lastModified_AmPolicy ]]
                then
                        $LN -nsf "$TARGET_DIR/$lastModified_AmPolicy" $SYMLINK_PATH3
                        symlinkedFile_AmPolicy=$lastModified_AmPolicy
                fi

		lastModified_AmPolicyDel=$(getLastModifiedFile amPolicyDelegation.access $SYMLINK_FILE4)
                if [[ $symlinkedFile_AmPolicyDel != $lastModified_AmPolicyDel ]]
                then
                        $LN -nsf "$TARGET_DIR/$lastModified_AmPolicyDel" $SYMLINK_PATH4
                        symlinkedFile_AmPolicyDel=$lastModified_AmPolicyDel
                fi

		lastModified_Entitlement=$(getLastModifiedFile entitlement.access $SYMLINK_FILE5)
                if [[ $symlinkedFile_Entitlement != $lastModified_Entitlement ]]
                then
                        $LN -nsf "$TARGET_DIR/$lastModified_Entitlement" $SYMLINK_PATH5
                        symlinkedFile_Entitlement=$lastModified_Entitlement
                fi

		lastModified_amAuthErr=$(getLastModifiedFile amAuthentication.error $SYMLINK_FILE6)
                if [[ $symlinkedFile_AmAuthError != $lastModified_amAuthErr ]]
                then
                        $LN -nsf "$TARGET_DIR/$lastModified_amAuthErr" $SYMLINK_PATH6
                        symlinkedFile_AmAuthError=$lastModified_amAuthErr
                fi

		lastModified_amPolicyErr=$(getLastModifiedFile amPolicy.error $SYMLINK_FILE7)
                if [[ $symlinkedFile_AmPolicyErr != $lastModified_amPolicyErr ]]
                then
                        $LN -nsf "$TARGET_DIR/$lastModified_amPolicyErr" $SYMLINK_PATH7
                        symlinkedFile_AmPolicyErr=$lastModified_amPolicyErr
                fi
	done
}

getLock

if [ "$LOCKED" == 0 ];
        then
        info "Exclusive lock obtained on script, continuing...."
else
        info "This Script appears to be locked by another process, exiting "
        info "Exiting with return code 1"
        exit 1
fi

trap "releaseLock" HUP QUIT TERM INT

updateSymLinks

#default exit
exit 0

