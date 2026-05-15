#!/bin/bash

# trim all mounted or at least root file systems which support it
# call this file with cron



function run(){
    local _FSTRIM _MAJOR_VERSION _START
    _MAJOR_VERSION="$(lsb_release -r | cut -f2 | cut -d'.' -f1)"

    [ "${_MAJOR_VERSION:?"Missing MAJOR_VERSION"}" -ge "16" ] \
        && _FSTRIM="fstrim -v --all" \
        || _FSTRIM="fstrim -v /"

    _START="${SECONDS}"
    readonly _FSTRIM _MAJOR_VERSION _START

    echo -e "$(date) - fstrim started: '$($_FSTRIM)' (duration: $(date -u -d @"$((${SECONDS} - $_START))" +'%-Hh %Mm %Ss'))"
}

run > /var/log/fstrim.log
