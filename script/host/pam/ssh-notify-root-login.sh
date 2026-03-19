#!/bin/bash

_FULL_SCRIPTNAME="$(readlink -f "${0}" 2> /dev/null)"
_SCRIPTNAME=${_FULL_SCRIPTNAME##*/}

_LOGFILE="/var/log/${_SCRIPTNAME?:"Missing SCRIPTNAME"}.log" 
_EMAIL_ADDRESS=""
_SLACK_WEBHOOK_URL=""
readonly _FULL_SCRIPTNAME _SCRIPTNAME



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

function setup() {
    local _COMMAND _PAM_FILE
    _COMMAND="session optional pam_exec.so ${_FULL_SCRIPTNAME?:"Missing FULL_SCRIPTNAME"}"
    _PAM_FILE="/etc/pam.d/sshd"
    readonly _COMMAND _PAM_FILE

    # Lines are already appended, so nothing is to do, therefore no setup.
    grep -Fq "/${_SCRIPTNAME?:"Missing SCRIPTNAME"}" "${_PAM_FILE:?"Missing PAM_FILE"}" \
        && return 1

    # Append command to call this script, which is the setup.
    [ -f "${_PAM_FILE}" ] \
        && echo -e "\n#Call this script on each ssh-login\n${_COMMAND}" >> "${_PAM_FILE}"

    return 0
}

if [ "$PAM_TYPE" != "close_session" ] && ! setup && [ "${PAM_USER}" != "" ] && [ "${PAM_USER}" == "root" ]; then
    _MESSAGE="[$(date --rfc-3339=seconds)] - Login from IP: '${PAM_RHOST}' as user 'root@$(hostname)'"

    log "${_MESSAGE}"
    sendEMail "${_MESSAGE}"
    sendSlackMessage "${_MESSAGE}"
fi
