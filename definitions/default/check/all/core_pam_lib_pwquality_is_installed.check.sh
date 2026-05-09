#!/bin/bash

_PKG_NAME='libpam-pwquality'

dpkg -l | grep -q -F "${_PKG_NAME}" 2> /dev/null \
    && exit 0

exit 1
