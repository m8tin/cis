#!/bin/bash



function doChecks(){
    local readonly _TMPDIR="${1:?"doChecks(): Missing parameter TMPDIR:"}"
    local readonly _COLOR="${2:-"monocrom"}"

    local _DATETIME=$(date +%H-%M-%S)

    mkdir -p ${_TMPDIR}
    rm ${_TMPDIR}/* > /dev/null 2>&1

    for check in /monitoring/checks/*.on
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

    if [ "${_COLOR}" == "color" ]; then
        #color is for console-output
        echo "-----------------------"
        if [ ${_FAILED} -ne 0 ]; then
            echo "MISSED?${_FAILED}#${_DATETIME}"
        else
            echo "MISSED?${_FAILED}#${_DATETIME}"
        fi
    else
        echo "MISSED?${_FAILED}#${_DATETIME}"
    fi

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
    return 0
}

main(){
    case "${1:-""}" in
        all)
            printf "Checks werden ausgeführt..." \
                && doChecks "/tmp/checks" color \
                && printf "Success" \
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
                && printf "Parameter '${1}' ist kein gültiger Befehl.\n"
            usage
            return 0
            ;;
    esac

    return 1
}

main "$@" || exit 1
