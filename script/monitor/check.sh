#!/bin/bash

# Folders always ends with an tailing '/'
_SCRIPT="$(readlink -f "${0}" 2> /dev/null)"
_CIS_ROOT="${_SCRIPT%%/script/monitor/*}/"               #Removes longest  matching pattern '/script/monitor/*' from the end
_CORE_SCRIPTS="${_CIS_ROOT:?"Missing CIS_ROOT"}core/"
_CURRENT_DOMAIN="$("${_CORE_SCRIPTS:?"Missing CORE_SCRIPTS"}printOwnDomain.sh")"
_DEFINITIONS="${_CIS_ROOT:?"Missing CIS_ROOT"}definitions/${_CURRENT_DOMAIN:?"Missing CURRENT_DOMAIN"}/"

# Checks for the entire domain
_DOMAIN_CHECKS="${_DEFINITIONS:?"Missing DEFINITIONS"}monitor/checks/"



function doChecks(){
    local readonly _TMPDIR="${1:?"doChecks(): Missing parameter TMPDIR:"}"

    local _DATETIME=$(date +%H-%M-%S)

    mkdir -p ${_TMPDIR}
    rm ${_TMPDIR}/* > /dev/null 2>&1

    for check in ${_DOMAIN_CHECKS}*.on
    do
        local _CHECK_FILENAME="${check##*/}"
        echo -n "${_CHECK_FILENAME%%.on}?" > "${_TMPDIR}/${_CHECK_FILENAME}"
        timeout -k 10s 20s bash ${check} >> "${_TMPDIR}/${_CHECK_FILENAME}" 2> /dev/null || echo "TIMEOUT#Timeout" >> "${_TMPDIR}/${_CHECK_FILENAME}" &
    done
    wait

    local _FAILED=0
    echo "CHECK?RESULT[#MESSAGE]:"
    echo "-----------------------"
    for resultFile in ${_TMPDIR}/*
    do
        cat "${resultFile}"
        grep -q "FAIL" ${resultFile} && _FAILED=$(expr ${_FAILED} + 1)
    done
    echo "MISSED?${_FAILED}#${_DATETIME}"

    rm -r ${_TMPDIR} > /dev/null 2>&1
    return 0
}

function usage(){
    printf "\nUsage: /monitoring/check.sh <command> <options>"
    echo
    echo "possible commands:"
    echo
    echo "- all"
    echo "    Executes all checks."
    echo "- auto <out_file>"
    echo "    Executes quiet all checks and saves the result in the given out_file."
    echo "      (e.g. add the following line to crontab: '* * * * * /cis/script/monitor/check.sh auto /var/www/html/check.txt'"
    echo "       to update the file '/var/www/html/check.txt' every minute as 'check.html' needs it.)"
    return 0
}

main(){
    case "${1:-""}" in
        all)
            echo "Checks werden ausgeführt..." \
                && echo \
                && doChecks "/tmp/checks" color \
                && echo \
                && echo "Success" \
                && return 0
            ;;
        auto)
            # If just a filename is given it is created in /tmp, because of 'cd /tmp' 
            cd /tmp \
                && doChecks "/tmp/checks$(date +%N)" > "$2.new" \
                && mv -f "$2.new" "$2" \
                && return 0
            return 1
            ;;
		*)
            [ "${1:+isset}" == "isset" ] \
                && echo "Parameter '${1}' ist kein gültiger Befehl."
            usage
            return 0
            ;;
    esac

    return 1
}

main "$@" || exit 1
