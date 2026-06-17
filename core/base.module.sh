#!/bin/bash

#WARNING: Used for core functionality in setup.sh
#         DO NOT rename the script and test changes well!



[ "${BASH_VERSINFO[0]}" -lt 4 ] \
    && echo "Version 4 or newer is required, bash has version : '${BASH_VERSION}'." >&2 \
    && exit 1

# Prevents loading this module twice
[ "${CIS[SET]}" == "ready" ] && return 0



function base.checkAllInputParameters() {
    local _ALLOWED_CHARS _ARG _SUCCESS
    # Global whitelist for all start-parameters ($1, $2, ...)
    _ALLOWED_CHARS='-[:alnum:]@/_.:'
    readonly _ALLOWED_CHARS

    _SUCCESS="true"
    for _ARG in "${@}"; do
        if [ -n "${_ARG}" ]; then
            # Has to start with an alphanumeric char '--' or '/'
            if [[ ! "${_ARG}" =~ ^(--|/)?[[:alnum:]] ]]; then
                echo "❌ Security base.checkAllInputParameters(): No special characters except '--' or '/' are allowed at the beginning of a parameter: '${_ARG}'" >&2
                _SUCCESS="false"
            fi
            # No forbidden character is allowed to remain
            if [ -n "${_ARG//[${_ALLOWED_CHARS}]/}" ]; then
                echo "❌ Security base.checkAllInputParameters(): Illegal character found in parameter: '${_ARG}'" >&2
                _SUCCESS="false"
            fi
        fi
    done

    [ "${_SUCCESS}" == "true" ] \
        && return 0

    return 1
}

function base.checkScriptforCorrectAssignments() {
    local _LN=0
    local _SUCCESS="true"

    while IFS= read -r _line || [ -n "${_line}" ]; do
        ((_LN++))

        [[ "${_line}" =~ '^[[:space:]]*#' ]] && continue # Comments are okay

        [[ "${_line}" =~ '^[-a-zA-Z0-9_]+=\"?\$\{?([0-9]+|@)' ]] && [[ ! "${_line}" =~ 'base.set' ]] \
            && echo "❌ line ${_LN}: direct assignment prohibited! Use 'base.set VARNAME VALUE REGEX' instead." >&2 \
            && _SUCCESS='false'

    done < "${0}"

    [ "${_SUCCESS}" == 'true' ] \
        && return 0

    return 1
}

function prepare.setCIS() {
    # Check precondition
    [ "${CIS[SET]:+isset}" != 'isset' ] \
        && base.abort "Array CIS was not initialized correctly."

    # Retrieves the variables for this module using 'BASH_SOURCE[0]', the infos about the script using '$0'.
    local _ROOT_TRUNK _FULLBASENAME _FULLSCRIPTNAME _CIS_ROOT
    _FULLBASENAME="$(realpath "${BASH_SOURCE[0]}" 2> /dev/null)"
    _FULLSCRIPTNAME="$(realpath "${0}" 2> /dev/null)"

    # Folders always ends with an tailing '/'
    _ROOT_TRUNK="${_FULLSCRIPTNAME%cis/*}"
    while true; do
        # Because we tried to cut the pattern 'cis/*', but nothing happened we know the pattern was not found.
        # So we can not derive root of cis from the script, but we can fall back to the module's own location.
        [ "${_FULLSCRIPTNAME}" == "${_ROOT_TRUNK}" ] \
            && _CIS_ROOT="${_FULLBASENAME%/*}/" \
            && _CIS_ROOT="${_CIS_ROOT%core/*}" \
            && break

        [ -d "${_ROOT_TRUNK}cis/core/" ] \
            && [ -d "${_ROOT_TRUNK}cis/definitions/" ] \
            && [ -d "${_ROOT_TRUNK}cis/states/" ] \
            && _CIS_ROOT="${_ROOT_TRUNK}cis/" \
            && break

        [ "${_ROOT_TRUNK}" == '/' ] \
            && base.abort '  Unable to find root folder of CIS!' 'This state was reached unexpected.'

        _ROOT_TRUNK="${_ROOT_TRUNK%cis/*}"
    done
    readonly _ROOT_TRUNK _FULLBASENAME _FULLSCRIPTNAME _CIS_ROOT

    CIS[ROOT]="${_CIS_ROOT}"
    CIS[DOMAIN]="$(base.printOwnDomain "${CIS[ROOT]:?"Missing global CIS_ROOT"}")"

    [ -z "${CIS[DOMAIN]}" ] \
        && echo \
        && echo "No domain could be found for this host:" \
        && echo "  This may be due to an incorrect configuration." \
        && echo \
        && return 1

    CIS[COREROOT]="${CIS[ROOT]}core/"
    CIS[MODULEROOT]="${CIS[ROOT]}module/"
    CIS[SCRIPTSROOT]="${CIS[ROOT]}script/"

    # Sets the valus of the global array 'CIS' and set it readonly
    CIS[ARGS]="${@}"
    CIS[HOME]="${HOME:-"/root"}/"
    CIS[HOST]="$(hostname -b)"
    CIS[USER]="$(whoami)"

    # Ensures each user is allowed to create 'his' folder.
    CIS[LOGDIR]="/tmp/${CIS[USER]:-"UNKNOWN"}/cis/"
    CIS[WORKDIR]="$(pwd)/"

    CIS[BASE]="${_FULLBASENAME:?"Missing FULLBASENAME"}"
    CIS[FULLSCRIPTNAME]="${_FULLSCRIPTNAME:?"Missing FULLSCRIPTNAME"}"

    # Like 'dirname ${CIS[FULLSCRIPTNAME]}'
    CIS[SCRIPTDIR]="${CIS[FULLSCRIPTNAME]%/*}/"

    # Like 'basename ${CIS[FULLSCRIPTNAME]}'
    CIS[SCRIPTNAME]="${CIS[FULLSCRIPTNAME]##*/}"

    CIS[DEFAULTDEFINITIONS]="${CIS[ROOT]}definitions/default/"
    CIS[DOMAINDEFINITIONS]="${CIS[ROOT]}definitions/${CIS[DOMAIN]:?"Missing DOMAIN"}/"
    CIS[DOMAINSTATES]="${CIS[ROOT]}states/${CIS[DOMAIN]}/"

    CIS[COMPOSITIONS]="${CIS[DOMAINDEFINITIONS]:?"Missing DOMAINDEFINITIONS"}compositions/"
    CIS[GENERICMONITORCHECKS]="${CIS[SCRIPTSROOT]:?"Missing SCRIPTROOT"}monitor/generic/"

    CIS[SET]='ready'
    # Sets the write protection of array 'CIS'
    declare -A -g -r CIS
    return 0
}

function prepare.setCOLOR() {
    # Check the procondition,
    [ "${COLOR[SET]:+isset}" != 'isset' ] \
        && base.abort "Array COLOR was not initialized correctly."

    # set the values into the global array 'COLOR',
    COLOR[NO]='\033[0m'
    COLOR[RED]='\033[0;31m'
    COLOR[GREEN]='\033[0;32m'
    COLOR[DARKYELLOW]='\033[0;33m'
    COLOR[BLUE]='\033[0;34m'
    COLOR[PURPLE]='\033[0;35m'
    COLOR[CYAN]='\033[0;36m'
    COLOR[LIGHTGREY]='\033[0;37m'
    COLOR[DARKGREY]='\033[1;30m'
    COLOR[LIGHTRED]='\033[1;31m'
    COLOR[LIGHTGREEN]='\033[1;32m'
    COLOR[YELLOW]='\033[1;33m'
    COLOR[LIGHTBLUE]='\033[1;34m'
    COLOR[WHITE]='\033[1;37m'

    # and define the array 'COLOR' as readonly.
    declare -A -g -r COLOR
    return 0
}

function prepare.setPATH() {
    local _GREP_PATH
    _GREP_PATH="${1:?"Missing parameter GREP_PATH"}"
    readonly _GREP_PATH
    # Fixes the paths, ...
    if [ -x ${_GREP_PATH} ]; then
        echo ":${PATH}:" | ${_GREP_PATH} -q ":/bin:" || export PATH="${PATH}:/bin" 2> /dev/null
        echo ":${PATH}:" | ${_GREP_PATH} -q ":/sbin:" || export PATH="${PATH}:/sbin" 2> /dev/null
        echo ":${PATH}:" | ${_GREP_PATH} -q ":/usr/bin:" || export PATH="${PATH}:/usr/bin" 2> /dev/null
        echo ":${PATH}:" | ${_GREP_PATH} -q ":/usr/sbin:" || export PATH="${PATH}:/usr/sbin" 2> /dev/null
        echo ":${PATH}:" | ${_GREP_PATH} -q ":/usr/local/bin:" || export PATH="${PATH}:/usr/local/bin" 2> /dev/null
        echo ":${PATH}:" | ${_GREP_PATH} -q ":/usr/local/sbin:" || export PATH="${PATH}:/usr/local/sbin" 2> /dev/null
        return 0
    fi
    return 1
}

function prepare.setREGEX() {
    # Check the procondition,
    [ "${REGEX[SET]:+isset}" != 'isset' ] \
        && base.abort "Array REGEX was not initialized correctly."

    # set the values into the global array 'REGEX',
    REGEX[COMMAND]='^([]a-zA-Z0-9[|/_:,." -]+)$'                 #WARNING: Escaping does not work properly here, so we need to position the special characters in a clever way.
    REGEX[COMPOSITION]='^[a-zA-Z]([a-zA-Z0-9_-]*[a-zA-Z0-9])?$'
    REGEX[DOMAIN]='^([a-zA-Z][a-zA-Z0-9\.-]*)?[a-zA-Z]{2,}$'
    REGEX[FULLDIRPATH]='^/([a-zA-Z0-9\._-]+/)*$'
    REGEX[SNAPSHOT]='^@[a-zA-Z]([a-zA-Z0-9\.:_-]*[a-zA-Z0-9])?$'
    REGEX[SYNCSNAPSHOT]='^@SYNC_[a-zA-Z0-9\.:_-]*[a-zA-Z0-9]$'
    REGEX[USER]='^[a-zA-Z]([-a-zA-Z0-9\._]*[a-zA-Z0-9])?$'
    REGEX[ZFS]='^[a-zA-Z]([a-zA-Z0-9\/_-]*[a-zA-Z0-9])?$'

    # and define the array 'REGEX' as readonly.
    declare -A -g -r REGEX
    return 0
}

function base.abort() {
    # Minimalmode in case of emergency
    [ "${COLOR[SET]:+isset}" != 'isset' ] \
        && printf -- "\n%b\n" "Script aborted during preparation (State: '${CIS[SET]:-""}')!" >&2  \
        && printf -- "  %b\n\n" "${@}" >&2 \
        && exit 1

    local _FULLSCRIPTNAME=$(realpath "${0}" 2> /dev/null)
    local _SCRIPTNAME="${_FULLSCRIPTNAME##*/}"

    [ "${1:+isset}" != "isset" ] \
        && base.printWithColor LIGHTRED "\nScript ${_SCRIPTNAME} aborted!\n\n" >&2 \
        && exit 1

    [ "${2:+isset}" != "isset" ] \
        && base.printWithColor LIGHTRED "\nScript ${_SCRIPTNAME} aborted!\n" >&2 \
        && base.printWithColor WHITE "${1:?"Missing parameter MESSAGE."}\n\n" >&2 \
        && exit 1

    [ "${3:+isset}" != "isset" ] \
        && base.printWithColor LIGHTRED "\nScript ${_SCRIPTNAME} aborted!\n" >&2 \
        && base.printWithColor WHITE "${1:?"Missing parameter MESSAGE."}\n\n" >&2 \
        && base.printWithColor CYAN "TIP: ${2:?"Missing parameter TIP."}\n" >&2 \
        && exit 1

    base.printWithColor LIGHTRED "\nScript ${_SCRIPTNAME} aborted!\n" >&2
    base.printWithColor WHITE "${1:?"Missing parameter MESSAGE."}\n\n" >&2
    base.printWithColor CYAN "TIP - ${2:?"Missing parameter TIP."}:\n" >&2
    while shift; do
        [ -z "${2:-""}" ] && break
        base.printWithColor LIGHTGREY "  ${2}\n" >&2
    done
    exit 1
}

function base.filterComments() {
    local _FILENAME
    _FILENAME="${1:?"base.filterComments() Missing first parameter FILENAME"}"
    readonly _FILENAME

    # Filters comments (# und ;) and empty lines, retuns the remaining content...
    grep -o "^[[:blank:]]*[^[:blank:]#;].\+$" "${_FILENAME}" \
        && return 0

    return 1
}

function base.loadModule() {
    local _MODULENAME _MODULEFULLNAME
    _MODULENAME="${1:?"Function base.loadModule(): Missing parameter MODULENAME."}"
    _MODULEFULLNAME="${CIS[MODULEROOT]:?"Function base.loadModule(): Missing CIS_MODULEROOT."}${_MODULENAME}.module.sh"
    readonly _MODULENAME _MODULEFULLNAME

    #module already is loaded => return
    declare -f "module.${_MODULENAME}" > /dev/null 2>&1 \
        && return 0

    #Iterates each function and checks for name-collisions with other programms or functions
    local _functionName _programPath
    for _functionName in $(grep "^[[:space:]]*function" "${_MODULEFULLNAME}" | cut -d' ' -f2 | cut -d'(' -f1); do
        _programPath="$(which "${_functionName}")"
        echo "${_programPath}" | grep -q "/${_functionName}"  \
            && echo "WARNING: Loading this module '${_MODULEFULLNAME}' hides the program '${_programPath}'."

        [ "${_functionName}" == "$(declare -F ${_functionName})" ] \
            && echo "WARNING: Loading this module '${_MODULEFULLNAME}' replaces the existing function '${_functionName}'."

        # Checks the convention of the function's names
        echo "${_functionName}" | grep -q "${_MODULENAME}." \
            && continue

        base.abort "Module ${_MODULEFULLNAME} does not comply the convention." "All function names has to start with '${_MODULENAME}.'."
    done

    #Command source actually loads the module.
    #  source <(sed 's/\bfunction \b/&.cis_/' "${_MODULEFULLNAME}") would rename the functions additionally...
    #Command eval creates a function which is used to determine if the module already is loaded
    source "${_MODULEFULLNAME}" \
        && eval "function module.${_MODULENAME}(){ declare -F | grep '${_MODULENAME}\.' >&2; }" \
        && return 0

    base.abort "Unable to load module '${_MODULEFULLNAME}'."
}

function base.log() {
    local _LOGLEVEL _LOGLEVEL_UPPER
    base.set _LOGLEVEL "${1}" '^(error|warn|info|debug)$'
    _LOGLEVEL_UPPER="${_LOGLEVEL:?"base.log(): Missing valid first parameter LOGLEVEL"}"
    _LOGLEVEL_UPPER="${_LOGLEVEL_UPPER^^}"
    readonly _LOGLEVEL_UPPER

    case "${CIS[LOGLEVEL]:-warn}" in
        debug) [ "${_LOGLEVEL_UPPER}" = "DEBUG" ] && echo "[${_LOGLEVEL_UPPER}] $(date +%H:%M:%S) - ${2}" >&2 ;& # Forces execution to continue in the next block
        info)  [ "${_LOGLEVEL_UPPER}" = "INFO"  ] && echo "[${_LOGLEVEL_UPPER}] $(date +%H:%M:%S) - ${2}" >&2 ;&
        warn)  [ "${_LOGLEVEL_UPPER}" = "WARN"  ] && echo "[${_LOGLEVEL_UPPER}] $(date +%H:%M:%S) - ${2}" >&2 ;&
        error) [ "${_LOGLEVEL_UPPER}" = "ERROR" ] && echo "[${_LOGLEVEL_UPPER}] $(date +%H:%M:%S) - ${2}" >&2 ;;
    esac
}

function base.printEnvironment() {
    # Check precondition
    [ "${CIS[SET]:+isset}" != 'isset' ] \
        && declare -A -g CIS=([SET]=unprepared) \
        && prepare.setCIS

    [ "${CIS[SET]:+isset}" != 'isset' ] \
        && return 1

    echo "Content of array CIS: (all folder-paths end with an tailing '/')"
    echo "----------------------------------------------------------------------------"
    for _KEY in "${!CIS[@]}"; do
        printf -- "  %s: %s\n" "CIS[${_KEY}]" "${CIS[${_KEY}]}"
    done
    return 0
}

function base.printModuleFunctions() {
    local _MODULENAME
    _MODULENAME="${1:?"Function base.printModuleFunctions(): Missing parameter MODULENAME."}"
    readonly _MODULENAME

    [ "${_MODULENAME}" = "base" ] \
        && declare -f $(declare -F | grep "${_MODULENAME}." | cut -d" " -f3) \
        && return 0

    # If module is loaded => continue
    declare -f "module.${_MODULENAME}" > /dev/null 2>&1 \
        && declare -f $(declare -F | grep "${_MODULENAME}." | cut -d" " -f3) \
        && return 0

    return 1
}

function base.printOwnDomain() {
    local _CIS_ROOT _OVERRIDE_DOMAIN_FILE
    _CIS_ROOT="${1:?"base.printOwnDomain(): Missing first parameter CIS_ROOT."}"
    _OVERRIDE_DOMAIN_FILE="${_CIS_ROOT:?"Missing CIS_ROOT"}overrideOwnDomain"
    readonly _CIS_ROOT _OVERRIDE_DOMAIN_FILE

    local _BOOT_DOMAIN _OVERRIDE_DOMAIN

    # There has to be one dot at least.
    _BOOT_DOMAIN="$(hostname -b | grep -F '.' | cut -d. -f2-)"

    # Take OVERRIDING_DOMAIN_FILE without empty lines and comments, then take the first line without leading spaces
    _OVERRIDE_DOMAIN="$(grep -vE '^[[:space:]]*$|^[[:space:]]*#' "${_OVERRIDE_DOMAIN_FILE}" 2> /dev/null | head -n 1 | xargs)"

    readonly _BOOT_DOMAIN _OVERRIDE_DOMAIN

    [ -n "${_OVERRIDE_DOMAIN}" ] \
        && [ "${_OVERRIDE_DOMAIN}" != "${_BOOT_DOMAIN}" ] \
        && printf -- "WARNING: Domain has been overridden by: %s\n\n" "${_OVERRIDE_DOMAIN_FILE}" >&2 \
        && echo "${_OVERRIDE_DOMAIN}" \
        && return 0

    [ -n "${_BOOT_DOMAIN}" ] \
        && echo "${_BOOT_DOMAIN}" \
        && return 0

    printf -- "It was impossible to find out the domain of this host, please prepare this host first.\n" >&2
    return 1
}

function base.printWithColor() {
    local _COLOR _COLOR_KEY _MESSAGE _NO_COLOR
    _COLOR_KEY="${1:?"base.printWithColor(): Missing first parameter COLOR."}"
    # It printing target is a terminal which supports more than 8 colors.
    if [ -t 1 ] \
        && [ "$(tput colors 2>/dev/null || echo 0)" -ge 8 ] \
        && [[ "$(declare -p COLOR 2>/dev/null)" == "declare -A"* ]] \
        && [ -n "${COLOR[${_COLOR_KEY}]}" ]
    then
        _COLOR="${COLOR[${_COLOR_KEY}]}"
        _NO_COLOR="${COLOR[NO]}"
    fi
    shift
    if [ $# -gt 0 ]; then
        _MESSAGE="$*"
    elif [ ! -t 0 ]; then
        # Read from stdin, if there is something in the pipe only.
        _MESSAGE=$(cat)
    fi

    printf -- "%b%b%b" "${_COLOR:-""}" "${_MESSAGE}" "${_NO_COLOR:-""}" \
        && return 0

    return 1
}

function base.set() {
    local _VARNAME="${1:?"base.set(): Missing first parameter VARNAME"}"
    local _CLEAN_VARNAME="${_VARNAME//[^a-zA-Z0-9_]/}"
    local _VALUE="${2}"
    local _REGEX="${3:?"base.set(): Missing third parameter REGEX"}"
    local _MODE="${4}"

    [ "${_VARNAME}" != "${_CLEAN_VARNAME}" ] \
        && echo "FAILURE - base.set(): Invalid name of variable: ${_VARNAME}" >&2 \
        && exit 1

    [ -z "${_VALUE}" ] \
        && [ "${_MODE}" == 'optional' ] \
        && readonly "${_CLEAN_VARNAME}" \
        && return 0

    # Sets the value to a global variable with name $_VARNAME
    [[ "${_VALUE}" =~ $_REGEX ]] \
        && printf -v "${_CLEAN_VARNAME}" -- "%s" "${_VALUE}" \
        && readonly "${_CLEAN_VARNAME}" \
        && return 0

    echo "FAILURE: - base.set(): Validation '${_REGEX}' failed for ${_VARNAME}" >&2
    exit 1
}

function base.explain() {
    local _MODULE_PREFIX
    _MODULE_PREFIX="${1:?"base.explain(): Missing first parameter MODULE_PREFIX"}"
    readonly _MODULE_PREFIX

    [ -z "${2}" ] \
        && echo "Then you can use these functions provided by this module inside your script:" \
        && echo "  (for function details run: './${_MODULE_PREFIX}.module.sh explain FUNCTION_NAME' )" \
        && echo "----------------------------------------------------------------------------" \
        && declare -F | grep -F "${_MODULE_PREFIX}." | cut -d" " -f3 | xargs -n1 printf -- "  %s\n" \
        && return 0

    [ "${2}" == 'explain' ] \
        && declare -F | grep -F "${_MODULE_PREFIX}." | cut -d" " -f3 | while read -r _FUNCTION; do

        [ "${3}" == "${_FUNCTION}" ] \
            && echo "Then you can use the function '${_FUNCTION}()' as follows:" \
            && echo "----------------------------------------------------------------------------" \
            && grep -B 10 -F "${_FUNCTION}()" "${_MODULE_PREFIX}.module.sh" | grep -E '^#.*' \
            && return 0
    done
}



# Check if this module was started correctly using source
if [ "${BASH_SOURCE[0]}" == "${0}" ]; then
    # Script was executed directly, e.g. by ./base.sh
    echo "FAILURE: you are using this module 'base.sh' in a wrong way."
    echo "    It is intended as a utility library and should not be called directly."
    echo
    echo "Usage: load the base module at the beginning of your script, like this:"
    echo "----------------------------------------------------------------------------"
    echo
    echo '#!/bin/bash'
    echo 'source /cis/core/base.module.sh'
    echo
    base.explain 'base' "${1}" "${2}"
    echo
    [ -z "${1}" ] && base.printEnvironment
    exit 1
elif [ "${CIS[SET]}" == "ready" ]; then
    base.abort "Module '${BASH_SOURCE[0]}' already loaded."
else
    # If not exists, define a global array 'COLOR'
    trap "base.abort '  User-initiated termination.'" INT \
        && declare -A -g COLOR=([SET]=unprepared) \
        && prepare.setCOLOR \
        && prepare.setPATH "/bin/grep" \
        && declare -A -g REGEX=([SET]=unprepared) \
        && prepare.setREGEX \
        && declare -A -g CIS=([SET]=unprepared) \
        && prepare.setCIS \
        && base.checkAllInputParameters "${@}" \
        && base.checkScriptforCorrectAssignments \
        || base.abort "The necessary preparations have failed."

    base.log debug "Module '${BASH_SOURCE[0]}' loaded by script: ${0}"
fi
