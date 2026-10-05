#!/bin/bash
source /cis/core/base.module.sh



# log.string values
#  - values mandatory: "log" "this test"
#
# Logs the given values to stderr if _MODE is '--interactive'.
# Additionally the input is written to the file '${_LOG_FILE_FULLNAME}', if it is defined.
#
# Custom line breaks are preserved,
# backslash-escaped characters are interpreted (e.g. '\n' or '\t'),
# but no line break is appended automatically. (see: log.line)
function log.string() {
    # Logverzeichnis bei Bedarf anlegen
    if [[ "${_LOG_FILE_FULLNAME}" == /* ]]; then
        mkdir -p "${_LOG_FILE_FULLNAME%/*}"
        if [ "${_MODE}" == "--interactive" ]; then
            printf -- "%b" "$*" >&2
            printf -- "%b" "$*" >> "${_LOG_FILE_FULLNAME:?"Missing LOG_FILE_FULLNAME"}"
        else
            printf -- "%b" "$*" >> "${_LOG_FILE_FULLNAME:?"Missing LOG_FILE_FULLNAME"}"
        fi
    else
        if [ "${_MODE}" == "--interactive" ]; then
            printf -- "%b" "$*" >&2
        fi
    fi
    return 0
}



# log.line values
#  - values mandatory: "log" "this test"
#
# Logs the given values to stderr if _MODE is '--interactive'.
# Additionally the input is written to the file '${_LOG_FILE_FULLNAME}', if it is defined.
#
# Custom line breaks are preserved,
# backslash-escaped characters are interpreted (e.g. '\n' or '\t'),
# and a line break is appended automatically (see: log.string).
function log.line() {
    # Logverzeichnis bei Bedarf anlegen
    if [[ "${_LOG_FILE_FULLNAME}" == /* ]]; then
        mkdir -p "${_LOG_FILE_FULLNAME%/*}"
        if [ "${_MODE}" == "--interactive" ]; then
            printf -- "%b\n" "$*" >&2
            printf -- "%b\n" "$*" >> "${_LOG_FILE_FULLNAME:?"Missing LOG_FILE_FULLNAME"}"
        else
            printf -- "%b\n" "$*" >> "${_LOG_FILE_FULLNAME:?"Missing LOG_FILE_FULLNAME"}"
        fi
    else
        if [ "${_MODE}" == "--interactive" ]; then
            printf -- "%b\n" "$*" >&2
        fi
    fi
    return 0
}



# log.success
#
# This function is meant to be uses in '&&' chain. So if the previous command was successful,
# and a log file '${_LOG_FILE_FULLNAME}' is defined, then a closing line will be appended.
# The appended line follows the monitoring convention 'OK' or 'OK#optional comment'.
#
# Additionally, the log file will be trimmed to the maximum number of lines defined in '${_LOG_MAX_LINES}'.
function log.success() {
    local -r _LOG_MAX_LINES_DEFAULT=100
    local    _LOG_MAX_LINES="${_LOG_MAX_LINES:-${_LOG_MAX_LINES_DEFAULT}}"

    # _LOG_MAX_LINES can be set globally
    if ! [[ "$_LOG_MAX_LINES" =~ ^[0-9]+$ ]]; then
        logln "WARNING: Invalid value _LOG_MAX_LINES. Fallback to default '${_LOG_MAX_LINES_DEFAULT}'."
        _LOG_MAX_LINES="${_LOG_MAX_LINES_DEFAULT}"
    fi

    if [ -f "${_LOG_FILE_FULLNAME}" ]; then
        printf -- "%b\n" "OK#Last update $(date "+%Y-%m-%d %H:%M:%S")" >> "${_LOG_FILE_FULLNAME}"

        # Rolling window
        local _TMP_FILE="${_LOG_FILE_FULLNAME}.tmp"
        tail -n "${_LOG_MAX_LINES}" "${_LOG_FILE_FULLNAME}" > "${_TMP_FILE}" \
            && mv "${_TMP_FILE}" "${_LOG_FILE_FULLNAME}"
    fi
    return 0
}



# log.fail
#
# This funtion is meant to be used at the end of a script in case of an failure.
# If a log file '${_LOG_FILE_FULLNAME}' is defined, then a closing line will be appended.
# The appended line follows the monitoring convention 'FAIL' or 'FAIL#optinal comment'.
function log.fail() {
    if [ -f "${_LOG_FILE_FULLNAME}" ]; then
        printf -- "%b\n" "FAIL#Check ${_LOG_FILE_FULLNAME}" >> "${_LOG_FILE_FULLNAME}"
    fi
    return 0
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
    base.explain 'log' "${1}" "${2}"
    echo
    exit 1
fi
