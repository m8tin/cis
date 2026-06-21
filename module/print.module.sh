#!/bin/bash
source /cis/core/base.module.sh



#Function, to highlight bad messages.
function print.bad() {
    local _MESSAGE="${@:?"print.bad(): Missing first parameter MESSAGE."}"

    base.printWithColor LIGHTRED "${_MESSAGE}" >&2 \
        && return 0

    return 1
}

#Function, for data.
function print.data() {
    local _MESSAGE="${@:?"print.data(): Missing first parameter MESSAGE."}"

    base.printWithColor DARKGREY "${_MESSAGE}" >&2 \
        && return 0

    return 1
}

#Function, to print done status.
function print.done() {
    base.printWithColor LIGHTGREEN "(done)\n" >&2 \
        && return 0

    return 1
}

#Function, for uncorrectable errors.
function print.error() {
    local _MESSAGE="${@:-""}"

    [ -z "${_MESSAGE:-""}" ] \
        && base.printWithColor LIGHTRED "ERROR!\n" >&2 \
        && return 0

    base.printWithColor LIGHTRED "ERROR:" >&2 \
        && base.printWithColor WHITE " ${_MESSAGE}\n" >&2 \
        && return 0

    return 1
}

#Function, for very important information.
function print.essential() {
    local _MESSAGE="${@:?"print.essential(): Missing first parameter MESSAGE."}"

    base.printWithColor LIGHTRED "${_MESSAGE}" >&2 \
        && return 0

    return 1
}

#Function, to print fail status.
function print.fail() {
    base.printWithColor LIGHTRED "(FAIL)\n" >&2 \
        && return 0

    return 1
}

#Function, for failures.
function print.failure() {
    [ "${1:+isset}" != "isset" ] \
        && base.printWithColor LIGHTRED "FAILURE (" >&2 \
        && base.printWithColor WHITE " ${CIS[SCRIPTNAME]}" >&2 \
        && base.printWithColor LIGHTRED ")!\n" >&2 \
        && return 0

    [ "${2:+isset}" != "isset" ] \
        && base.printWithColor LIGHTRED "FAILURE (" >&2 \
        && base.printWithColor WHITE "${CIS[SCRIPTNAME]}" >&2 \
        && base.printWithColor LIGHTRED "): ${1:?"Missing parameter MESSAGE."}\n" >&2 \
        && return 0

    base.printWithColor LIGHTRED "FAILURE (" >&2
    base.printWithColor WHITE "${CIS[SCRIPTNAME]}" >&2
    base.printWithColor LIGHTRED "): ${1:?"Missing parameter MESSAGE."}\n" >&2
    base.printWithColor CYAN "TIP: ${2:?"Missing parameter TIP."}\n" >&2
    while [ -n "${3}" ]; do
        base.printWithColor LIGHTGREY "  ${3:-""}\n" >&2
        shift
    done
    return 0
}

#Function, to finish a script.
function print.finish() {
    local _SCRIPTNAME="${CIS[SCRIPTNAME]:?"print.finish(): Missing CIS[SCRIPTNAME]."}"

    base.printWithColor WHITE "\nScript ${_SCRIPTNAME}: " >&2 \
        && base.printWithColor LIGHTGREEN "successful!\n\n" >&2 \
        && return 0

    return 1
}

#Function, to highlight good messages.
function print.good() {
    local _MESSAGE="${@:?"print.good(): Missing first parameter MESSAGE."}"

    base.printWithColor LIGHTGREEN "${_MESSAGE}" >&2 \
        && return 0

    return 1
}

#Function, for highlighted messages.
function print.highlight() {
    local _MESSAGE="${@:?"print.highlight(): Missing first parameter MESSAGE."}"

    base.printWithColor WHITE "${_MESSAGE}" >&2 \
        && return 0

    return 1
}

#Function, for important information.
function print.important() {
    local _MESSAGE="${@:?"print.important(): Missing first parameter MESSAGE."}"

    base.printWithColor YELLOW "${_MESSAGE}" >&2 \
        && return 0

    return 1
}

#Function, for normal information.
function print.info() {
    local _MESSAGE="${1:?"print.info(): Missing first parameter MESSAGE."}"
    shift
    local _DECRIPTION="${@:-""}"

    [ -z "${_DECRIPTION:-""}" ] \
        && base.printWithColor LIGHTBLUE "INFO:" >&2 \
        && base.printWithColor WHITE " ${_MESSAGE}\n" >&2 \
        && return 0

    base.printWithColor LIGHTBLUE "INFO:" >&2 \
        && base.printWithColor WHITE " ${_MESSAGE}:\n" >&2 \
        && base.printWithColor LIGHTGREY "${_DECRIPTION}\n" >&2 \
        && return 0

    return 1
}

#Function, for normal messages.
function print.message() {
    local _MESSAGE="${@:?"print.message(): Missing first parameter MESSAGE."}"

    base.printWithColor LIGHTGREY "${_MESSAGE}" >&2 \
        && return 0

    return 1
}

#Function, for additional information.
function print.optional() {
    local _MESSAGE="${@:?"print.optional(): Missing first parameter MESSAGE."}"

    base.printWithColor LIGHTBLUE "${_MESSAGE}" >&2 \
        && return 0

    return 1
}

#Function, to start a script.
function print.start() {
    local _MESSAGE="${@:-""}"
    local _SERVICE="$(echo "${_SCRIPTDIR##${CIS[ROOT]:?"print.start(): Missing CIS[ROOT]"}/}" | tr '[:lower:]' '[:upper:]')"
    local _COMMAND="${CIS[SCRIPTNAME]:?"print.start(): Missing CIS[SCRIPTNAME]."}"

    [ -z "${_MESSAGE:-""}" ] \
        && base.printWithColor YELLOW "${_SERVICE} ${_COMMAND}:\n\n" >&2 \
        && return 0

    base.printWithColor YELLOW "${_SERVICE} ${_COMMAND}:\n" >&2 \
        && base.printWithColor LIGHTBLUE "${_MESSAGE}\n\n" >&2 \
        && return 0

    return 1
}

#Function, for successful messages.
function print.success() {
    local _MESSAGE="${@:-""}"

    [ -z "${_MESSAGE:-""}" ] \
        && base.printWithColor LIGHTGREEN "SUCCESS!\n" >&2 \
        && return 0

    base.printWithColor LIGHTGREEN "SUCCESS:" >&2 \
        && base.printWithColor WHITE " ${_MESSAGE}\n" >&2 \
        && return 0

    return 1
}

#Function, for tips.
function print.tip() {
    local _MESSAGE="${1:?"print.tip(): Missing first parameter MESSAGE."}"

    base.printWithColor CYAN "TIP:" >&2 \
        && base.printWithColor WHITE " ${_MESSAGE}\n" >&2
    while [ -n "${2}" ]; do
        base.printWithColor LIGHTGREY "  ${2}\n" >&2 \
            && shift \
            && continue
        return 1
    done

    return 0
}

#Function, for warnings.
function print.warn() {
    local _MESSAGE="${@:?"print.warn(): Missing first parameter MESSAGE."}"

    base.printWithColor YELLOW "WARNING:" >&2 \
        && base.printWithColor WHITE " ${_MESSAGE}\n" >&2 \
        && return 0

    return 1
}



# Check if this module was started correctly using source
if [ "${BASH_SOURCE[0]}" == "${0}" ]; then
    # Script was executed directly
    echo "FAILURE: you are using this module 'print.module.sh' in a wrong way."
    echo "    It is intended as a utility library and should not be called directly."
    echo
    echo "Usage: Call this module at the beginning of your script e.g. like this:"
    echo
    echo '    #!/bin/bash'
    echo '    source /cis/core/base.module.sh'
    echo
    echo '    #Loads this module'
    echo '    base.loadModule print'
    echo
    base.explain 'print' "${1}" "${2}"
    echo
    exit 1
fi
