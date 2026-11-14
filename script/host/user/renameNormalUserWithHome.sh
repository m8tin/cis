#!/bin/bash
source /cis/core/base.module.sh
base.loadModule print



# sanitizes all parameters
declare -A EXPECTED_ARGS=(
    ["--current"]="required: current name of the user to rename.::${REGEX[USER]}"
        ["--new"]="required: new name of the user.::${REGEX[USER]}"
)
base.readArguments "${@}"

print.highlight "Rename user ${ARGS[current]} to ${ARGS[new]}: ... " \
    && usermod --login "${ARGS[new]}" "${ARGS[current]}" \
    && groupmod --new-name "${ARGS[new]}" "${ARGS[current]}" \
    && usermod --home "/home/${ARGS[new]}" --move-home "${ARGS[new]}" \
    && mv -f "/home/${ARGS[current]}" "/home/${ARGS[new]}" \
    && print.done \
    && exit 0

print.fail
exit 1
