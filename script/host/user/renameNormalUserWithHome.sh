#!/bin/bash
source /cis/core/base.module.sh
base.loadModule print



base.set OLD_USER "${1}" "${REGEX[USER]}"
base.set NEW_USER "${2}" "${REGEX[USER]}"

print.highlight "Rename user ${OLD_USER} to ${NEW_USER}: ... " \
    && usermod --login "${NEW_USER}" "${OLD_USER}" \
    && groupmod --new-name "${NEW_USER}" "${OLD_USER}" \
    && usermod --home "/home/${NEW_USER}" --move-home "${NEW_USER}" \
    && mv -f "/home/${OLD_USER}" "/home/${NEW_USER}" \
    && print.done \
    && exit 0

print.fail
exit 1
