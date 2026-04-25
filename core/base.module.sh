#!/bin/bash
[ "${BASH_VERSINFO[0]}" -lt 4 ] \
    && echo "Version 4 or newer is required, bash has version : '${BASH_VERSION}'." >&2 \
    && exit 1



function checkAllInputParameters() {
    local _ALLOWED_CHARS _ARG _SUCCESS
    # Global whitelist for all start-parameters ($1, $2, ...)
    _ALLOWED_CHARS='-[:alnum:]_.:'
    readonly _ALLOWED_CHARS

    _SUCCESS="true"
    for _ARG in "${@}"; do
        if [[ -n "${_ARG}" ]]; then
            # Has to start with an alphanumeric char or --
            if [[ ! "${_ARG}" =~ ^[[:alnum:]] ]] && [[ ! "${_ARG}" =~ ^--[[:alnum:]] ]]; then
                echo "❌ Security: No special character is allowed at the bginning of the parameter: '${_ARG}'" >&2
                _SUCCESS="false"
            fi
            # No forbidden character is allowed to remain
            if [[ -n "${_ARG//[${_ALLOWED_CHARS}]/}" ]]; then
                echo "❌ Security: Illegal character found in parameter: '${_ARG}'" >&2
                _SUCCESS="false"
            fi
        fi
    done

    [ "${_SUCCESS}" == "true" ] \
        && return 0

    return 1
}

function checkScriptforCorrectAssignments() {
    local _LN=0
    local _SUCCESS="true"

    while IFS= read -r _line || [[ -n "${_line}" ]]; do
        ((_LN++))

        [[ ! "${_line}" =~ ^.*(=\$|=\"\$).*$ ]] && continue # Assignments only

        [[ "${_line}" =~ ^[[:space:]]*# ]] && continue # Comments are okay

        [[ "${_line}" =~ ^[[:space:]]+[a-zA-Z0-9_]+=[^\ ]+ ]] && continue # Allow assignments in functions

        [[ "${_line}" =~ ^[a-zA-Z0-9_]+=[^\ ]+ ]] && [[ ! "${_line}" =~ "base.set" ]] \
            && echo "❌ line ${_LN}: direct assignment prohibited! Use 'base.set VARNAME VALUE REGEX' instead." >&2 \
            && _SUCCESS="false"

    done < "${0}"

    [ "${_SUCCESS}" == "true" ] \
        && return 0

    return 1
}

function prepare.setCIS() {
    # Check precondition
    [[ "${CIS[SET]:+isset}" != "isset" ]] \
        && base.abort "Array CIS was not initialized correctly."

    # Retrieves the variables for this module using 'BASH_SOURCE[0]', the infos about the script using '$0'.
    local _CISROOT _FULLBASENAME _FULLSCRIPTNAME
    _FULLBASENAME=$(readlink -e "${BASH_SOURCE[0]}" 2> /dev/null)
    _FULLSCRIPTNAME=$(readlink -e "${0}" 2> /dev/null)
    _CISROOT=$(echo "${_FULLSCRIPTNAME}" | grep -o '^.*/cis/')
    readonly _CISROOT _FULLBASENAME _FULLSCRIPTNAME

    # Folders always ends with an tailing '/'
    CIS[ROOT]="${_CISROOT:?"Missing CISROOT"}"
    CIS[COREROOT]="${CIS[ROOT]}core/"
    CIS[SCRIPTSROOT]="${CIS[ROOT]}script/"
    CIS[DOMAIN]=$("${CIS[COREROOT]}"printOwnDomain.sh)
    CIS[MODULEDIR]="${CIS[ROOT]}module/"

    [ -z "${CIS[DOMAIN]}" ] \
        && echo \
        && echo "No domain could be found for this host:" \
        && echo "  This may be due to an incorrect configuration." \
        && echo \
        && return 1

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
    CIS[DOMAINDEFINITIONS]="${CIS[ROOT]}definitions/${CIS[DOMAIN]}/"
    CIS[DOMAINSTATES]="${CIS[ROOT]}states/${CIS[DOMAIN]}/"

    CIS[SET]="normal"
    # Sets the write protection of array 'CIS'
    declare -A -g -r CIS
    return 0
}

function prepare.setCOLOR() {
    # Check the procondition,
    [[ "${COLOR[SET]:+isset}" != "isset" ]] \
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

function base.abort() {
    # Minimalmode in case of emergency
    [[ "${COLOR[SET]:+isset}" != "isset" ]] \
        && printf %b "\nScript aborted during preparation (State: '${CIS[SET]:-""}')!\n" >&2  \
        && printf %b "  ${@}\n\n" >&2 \
        && exit 1

    local _FULLSCRIPTNAME=$(readlink -e "${0}" 2> /dev/null)
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
    _MODULEFULLNAME="${CIS[MODULEDIR]:?"Function base.loadModule(): Missing CISMODULEDIR."}/${_MODULENAME}.module.sh"
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
    base.set _LOGLEVEL "${1}" '^(error|warn|info|debug)$' || exit 1
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
    [[ "${CIS[SET]:+isset}" != "isset" ]] \
        && declare -A -g CIS=([SET]=unprepared) \
        && prepare.setCIS

    [[ "${CIS[SET]:+isset}" != "isset" ]] \
        && return 1

    echo "Content of array CIS:"
    echo "---------------------"
    for _KEY in "${!CIS[@]}"; do
        printf "  %s\n" "CIS[${_KEY}]: ${CIS[${_KEY}]}\n"
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

function base.printWithColor() {
    local _COLOR _COLOR_KEY _MESSAGE _NO_COLOR
    _COLOR_KEY="${1:?"log.color(): Missing first parameter COLOR."}"
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

    printf "%b%b%b" "${_COLOR:-""}" "${_MESSAGE}" "${_NO_COLOR:-""}" \
        && return 0

    return 1
}

function base.set() {
    local _VARNAME="${1:?"base.set(): Missing first parameter VARNAME"}"
    local _VALUE="${2}"
    local _REGEX="${3:?"base.set(): Missing third parameter REGEX"}"

    # Sets the value to a global variable with name $_VARNAME
    [[ "${_VALUE}" =~ $_REGEX ]] \
        && printf -v "${_VARNAME}" "%s" "${_VALUE}" \
        && readonly "${_VARNAME}" \
        && return 0

    echo "❌ Security: Validation '$_REGEX' failed for ${_VARNAME}" >&2
    exit 1
}



# Check if this module was started correctly using source
if [ "${BASH_SOURCE[0]}" == "${0}" ]; then
    # Script was executed directly, e.g. by ./base.sh
    echo "FAILURE: you are using this module 'base.sh' in a wrong way."
    echo "    It is intended as a utility library and should not be called directly."
    echo
    echo "Usage: Call the base module at the beginning of your script, like this:"
    echo "-----------------------------------------------------------------------"
    echo
    echo '#!/bin/bash'
    echo 'source /cis/core/base.module.sh'
    echo
    echo
    base.printEnvironment
    echo
    echo "Now you can use the functions provided by this module inside your script:"
    echo "-------------------------------------------------------------------------"
    declare -F | grep "base." | cut -d" " -f3 | xargs -n1 printf "  %s\n"
    exit 1
else
    # If not exists, define a global array 'COLOR'
    trap "base.abort '  User-initiated termination.'" INT \
        && checkAllInputParameters "${@}" \
        && declare -A -g COLOR=([SET]=unprepared) \
        && prepare.setCOLOR \
        && prepare.setPATH "/bin/grep" \
        && declare -A -g CIS=([SET]=unprepared) \
        && prepare.setCIS \
        && checkScriptforCorrectAssignments \
        || base.abort "The necessary preparations have failed."

    base.log debug "Module '${BASH_SOURCE[0]}' loaded by script: ${0}"
fi
