#!/bin/bash

_PKG_NAME='libpam-google-authenticator'

dpkg -l | grep -q -F "${_PKG_NAME}" 2> /dev/null \
    && exit 0

exit 1
