
#!/bin/bash

#Function, to highlight bad messages.
function log.bad() {
    local _MESSAGE="${@:?"log.bad(): Missing first parameter MESSAGE."}"

    base.printWithColor LIGHTRED "${_MESSAGE}" >&2 \
        && return 0

    return 1
}

#Function, for data.
function log.data() {
    local _MESSAGE="${@:?"log.data(): Missing first parameter MESSAGE."}"

    base.printWithColor LIGHTGREY "${_MESSAGE}" >&2 \
        && return 0

    return 1
}

#Function, for uncorrectable errors.
function log.error() {
    local _MESSAGE="${@:-""}"

    [ -z "${_MESSAGE:-""}" ] \
        && base.printWithColor LIGHTRED "ERROR!\n" >&2 \
        && return 0

    base.printWithColor LIGHTRED "ERROR!\n" >&2 \
        && base.printWithColor WHITE "  ${_MESSAGE}\n" >&2 \
        && return 0

    return 1
}

#Function, for very important information.
function log.essential() {
    local _MESSAGE="${@:?"log.essential(): Missing first parameter MESSAGE."}"

    base.printWithColor LIGHTRED "${_MESSAGE}" >&2 \
        && return 0

    return 1
}

#Function, for failures.
function log.failure() {
    local _MESSAGE="${@:-""}"

    [ -z "${_MESSAGE:-""}" ] \
        && base.printWithColor LIGHTRED "FAILURE!\n" >&2 \
        && return 0

    base.printWithColor LIGHTRED "FAILURE!\n" >&2 \
        && base.printWithColor WHITE "  ${_MESSAGE}\n" >&2 \
        && return 0

    return 1
}

#Function, to finish a script.
function log.finish() {
    local _SCRIPTNAME="${CIS[SCRIPTNAME]:?"log.finish(): Missing CIS[SCRIPTNAME]."}"

    base.printWithColor WHITE "\nScript ${_SCRIPTNAME}: " >&2 \
        && base.printWithColor LIGHTGREEN "successful!\n\n" >&2 \
        && return 0

    return 1
}

#Function, to highlight good messages.
function log.good() {
    local _MESSAGE="${@:?"log.good(): Missing first parameter MESSAGE."}"

    base.printWithColor LIGHTGREEN "${_MESSAGE}" >&2 \
        && return 0

    return 1
}

#Function, for important information.
function log.important() {
    local _MESSAGE="${@:?"log.important(): Missing first parameter MESSAGE."}"

    base.printWithColor YELLOW "${_MESSAGE}" >&2 \
        && return 0

    return 1
}

#Function, for normal information.
function log.info(){
    local _MESSAGE="${1:?"log.info(): Missing first parameter MESSAGE."}"
    shift
    local _DECRIPTION="${@:-""}"

    [ -z "${_DECRIPTION:-""}" ] \
        && base.printWithColor LIGHTBLUE "INFO:\n" >&2 \
        && base.printWithColor WHITE "  ${_MESSAGE}\n" >&2 \
        && return 0

    base.printWithColor LIGHTBLUE "INFO - " >&2 \
        && base.printWithColor WHITE "${_MESSAGE}:\n" >&2 \
        && base.printWithColor LIGHTGREY "${_DECRIPTION}\n" >&2 \
        && return 0

    return 1
}

#Function, for highlighted messages.
function log.message(){
    local _MESSAGE="${@:?"log.message(): Missing first parameter MESSAGE."}"

    base.printWithColor WHITE "${_MESSAGE}" >&2 \
        && return 0

    return 1
}

#Function, for additional information.
function log.optional(){
    local _MESSAGE="${@:?"log.optional(): Missing first parameter MESSAGE."}"

    base.printWithColor LIGHTBLUE "${_MESSAGE}" >&2 \
        && return 0

    return 1
}

#Function, to start a script.
function log.start(){
    local _MESSAGE="${@:-""}"
    local _CISROOT="${CIS[ROOT]:?"log.start(): Missing CIS[ROOT]."}"
    local _SCRIPTDIR="${CIS[SCRIPTDIR]:?"log.start(): Missing CIS[SCRIPTDIR]."}"
    local _SERVICE="$(echo "${_SCRIPTDIR##${_CISROOT}/}" | tr '[:lower:]' '[:upper:]')"
    local _COMMAND="${CIS[SCRIPTNAME]:?"log.start(): Missing CIS[SCRIPTNAME]."}"

    [ -z "${_MESSAGE:-""}" ] \
        && base.printWithColor YELLOW "${_SERVICE} ${_COMMAND}:\n\n" >&2 \
        && return 0

    base.printWithColor YELLOW "${_SERVICE} ${_COMMAND}:\n" >&2 \
        && base.printWithColor LIGHTBLUE "${_MESSAGE}\n\n" >&2 \
        && return 0

    return 1
}

#Function, for successful messages.
function log.success(){
    local _MESSAGE="${@:-""}"

    [ -z "${_MESSAGE:-""}" ] \
        && base.printWithColor LIGHTGREEN "SUCCESS!\n" >&2 \
        && return 0

    base.printWithColor LIGHTGREEN "SUCCESS!\n" >&2 \
        && base.printWithColor WHITE "  ${_MESSAGE}\n" >&2 \
        && return 0

    return 1
}

#Function, for tips.
function log.tip(){
    local _MESSAGE="${1:?"log.tip(): Missing first parameter MESSAGE."}"

    base.printWithColor CYAN "TIP:\n" >&2
    while [ "${_MESSAGE:-""}" != "" ]; do
        base.printWithColor LIGHTGREY "  ${_MESSAGE}\n" >&2 \
            && shift \
            && _MESSAGE="${1:-""}" \
            && continue
        return 1
    done

    return 0
}

#Function, for warnings.
function log.warn(){
    local _MESSAGE="${@:?"log.warn(): Missing first parameter MESSAGE."}"

    base.printWithColor YELLOW "WARNING:\n" >&2 \
        && base.printWithColor WHITE "  ${_MESSAGE}\n" >&2 \
        && return 0

    return 1
}



# Check if this module was started correctly using source
if [ "${BASH_SOURCE[0]}" == "${0}" ]; then
    # Script was executed directly
    echo "FAILURE: you are using this module 'log.module.sh' in a wrong way."
    echo "    It is intended as a utility library and should not be called directly."
    echo
    echo "Usage: Call this module at the beginning of your script e.g. like this:"
    echo
    echo '    #!/bin/bash'
    echo '    source /cis/core/base.module.sh'
    echo
    echo '    #Loads this module'
    echo '    base.loadModule log'
    echo
    echo "Now you can use the functions provided by this module inside your script:"
    echo "-------------------------------------------------------------------------"
    declare -F | grep "log." | cut -d" " -f3
    exit 1
fi
