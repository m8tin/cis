#!/bin/bash

[ "$(id -u)" != "0" ] \
    && sudo "${0}" \
    && exit 0



_SETUP="$(readlink -f "${0}" 2> /dev/null)"

# Folders always ends with an tailing '/'
_CIS_ROOT="${_SETUP%%/script/monitor/*}/"             #Removes longest  matching pattern '/script/monitor/*' from the end
_DOMAIN="$("${_CIS_ROOT:?"Missing CIS_ROOT"}core/printOwnDomain.sh")"
_DEFINITIONS="${_CIS_ROOT:?"Missing CIS_ROOT"}definitions/${_DOMAIN:?"Missing DOMAIN"}/"



function checkPreconditions() {
    [ -d "${_DEFINITIONS:?"Missing DEFINITIONS"}monitor/checks" ] \
        && return 0

    echo "No folder for your defined checks found: ${_DEFINITIONS:?"Missing DEFINITIONS"}monitor/checks"
    echo "Please create it and add all your custom monitoring checks there, following this convention: 'NAME_OF_THE_CHECK.on'"
    echo "A check has to be switched 'on' to be executed, so you can rename a check to 'NAME_OF_THE_CHECK.off' and it will be ignored."
    echo
    echo "You can copy the file '/cis/script/monitor/checks/EXAMPLE_CHECK.off' to your check definitions folder and modify it."
    return 1
}



function printSelectedDefinition() {
    local _FILE_DEFINED_DOMAIN _FILE_DEFINED_DEFAULT
    _FILE_DEFINED_DOMAIN="${_DEFINITIONS:?"Missing DEFINITIONS"}monitor/${1:?"Missing CURRENT_FULLFILE"}"
    _FILE_DEFINED_DEFAULT="${_CIS_ROOT:?"Missing CIS_ROOT"}script/monitor/${1:?"Missing CURRENT_FULLFILE"}"
    readonly _FILE_DEFINED_DOMAIN _FILE_DEFINED_DEFAULT

    [ -s "${_FILE_DEFINED_DOMAIN}" ] \
        && echo "${_FILE_DEFINED_DOMAIN}" \
        && return 0

    [ -s "${_FILE_DEFINED_DEFAULT}" ] \
        && echo "${_FILE_DEFINED_DEFAULT}" \
        && return 0

    return 1
}

function setupPublicFile() {
    ! [ -d "/var/www/html" ] \
        && echo "Missing folder '/var/www/html'. Is a webserver installed?" \
        && return 1

    [ -L "/var/www/html/${1:?"Missing filename"}" ] \
        && [ "$(readlink -f /var/www/html/${1:?"Missing filename"})" == "$(printSelectedDefinition ${1:?"Missing filename"})" ] \
        && echo "Link '/var/www/html/${1:?"Missing filename"}' already exists pointing to the expected file:" \
        && echo "  - '$(readlink -f /var/www/html/${1:?"Missing filename"})'" \
        && return 0

    ln -f -s "$(printSelectedDefinition ${1:?"Missing filename"})" "/var/www/html/${1:?"Missing filename"}" \
        && echo "Link '/var/www/html/${1:?"Missing filename"}' created successfully:" \
        && echo "  - '$(readlink -f /var/www/html/${1:?"Missing filename"})'" \
        && return 0
}

echo "Setup the monitoring host that monitors the others ... " \
    && checkPreconditions \
    && setupPublicFile "check.html" \
    && setupPublicFile "check.css" \
    && setupPublicFile "logo.png" \
    && exit 0

exit 1
