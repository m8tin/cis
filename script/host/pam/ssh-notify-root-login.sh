#!/bin/bash
source /cis/core/base.module.sh

_LOGFILE="/var/log/${CIS[SCRIPTNAME]?:"Missing SCRIPTNAME"}.log"
_EMAIL_ADDRESS=""
_SLACK_WEBHOOK_URL=""



function log() {
    local _MESSAGE
    _MESSAGE="${1:?"sendEMail(): Missing first parameter MESSAGE"}"
    readonly _MESSAGE

    [ "${_LOGFILE}" == "" ] \
        && return 1

    echo "${_MESSAGE}" >> "${_LOGFILE}" \
        && return 0

    return 1
}

function sendEMail() {
    local _SUBJECT _MESSAGE
    _SUBJECT="${1:?"sendEMail(): Missing first parameter SUBJECT"}"
    _MESSAGE="${2}"
    readonly _SUBJECT _MESSAGE

    [ "${_EMAIL_ADDRESS}" == "" ] \
        && return 1

    # Needs: apt install mailutils
    echo "${_MESSAGE}" | mail -s "${_SUBJECT}" "${_EMAIL_ADDRESS}" \
        && return 0

    return 1
}

function sendSlackMessage() {
    local _MESSAGE _ICON
    _MESSAGE="${1:?"Missing first parameter MESSAGE"}"
    _ICON=":exclamation:"
    readonly _MESSAGE _ICON

    [ "${_SLACK_WEBHOOK_URL}" == "" ] \
        && return 1

    # Needs: apt install curl
    curl -X POST --data-urlencode "payload={\"icon_emoji\": \"${_ICON}\", \"text\": \"${_MESSAGE}\"}" "${_SLACK_WEBHOOK_URL}" \
        && return 0

    return 1
}

function notify() {
    if [ "$PAM_TYPE" != "close_session" ] && [ "${PAM_USER}" != "" ]; then

        # Log root logins only
        [ "${PAM_USER}" != "root" ] \
            && exit 0

        # Skip logins from private IPs
        echo "${PAM_RHOST}" | grep -Eq "^192\.168\..*$" \
            && exit 0

        _MESSAGE="[$(date --rfc-3339=seconds)] - Login from IP: '${PAM_RHOST}' as user 'root@$(hostname)'"

        log "${_MESSAGE}"
        sendEMail "${_MESSAGE}"
        sendSlackMessage "${_MESSAGE}"
        return 0
    fi
    return 1
}

function setup() {
    local _COMMAND _PAM_FILE
    _COMMAND="session optional pam_exec.so ${CIS[FULLSCRIPTNAME]?:"Missing FULL_SCRIPTNAME"} --notify"
    _PAM_FILE="/etc/pam.d/sshd"
    readonly _COMMAND _PAM_FILE

    ! [ -f "${_PAM_FILE}" ] \
        && printf "FAILURE: Missing file: %s\n" "${_PAM_FILE:?"Missing PAM_FILE"}" >&2 \
        && exit 1

    # Lines are already appended, so nothing is to do, therefore no setup.
    grep -q -F "/${CIS[SCRIPTNAME]?:"Missing SCRIPTNAME"}" "${_PAM_FILE}" \
        && return 1

    # Append command to call this script, which is the setup.
    printf "Appending the following command to file '%s':\n  - %s\n" "${_PAM_FILE}" "${_COMMAND}" >&2 \
        && printf "\n#Call this script on each ssh-login\n%s\n" "${_COMMAND}" >> "${_PAM_FILE}" \
        && printf "SUCCESS: Setup completed.\n" >&2 \
        && return 0

    printf "FAILURE: Setup of '%s' failed.\n" "${CIS[SCRIPTNAME]}" >&2
    exit 1
}

case "${1}" in

  --notify)
    notify && exit 0
    exit 1
    ;;

  --setup)
    setup && exit 0
    exit 1
    ;;

  *)
    echo "Run '${CIS[SCRIPTNAME]} --setup' to register this script."
    exit 0
    ;;

esac
