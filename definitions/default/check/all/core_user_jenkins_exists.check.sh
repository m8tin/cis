#!/bin/bash

_CURRENT_USER='jenkins'

[ "$(id -u)" != "0" ] \
    && printf "(INSUFFICENT RIGHTS) " \
    && exit 1

id -u "${_CURRENT_USER}" > /dev/null 2>&1 \
    && exit 0

exit 1
