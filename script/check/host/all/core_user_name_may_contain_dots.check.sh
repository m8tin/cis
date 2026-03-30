#!/bin/bash

_FILE_NAME='/etc/adduser.conf'

# The first expression should filter the line conaining the key.
#   - here a regular expression (-E) is used to enforce the line starts with the key.
# Second expression looks for the uninterpreted fix string (-F), but without output.
grep -E '^NAME_REGEX=.*$' "${_FILE_NAME}" | grep -q -F '^[a-z][-a-z0-9_.]*\$?$' 2> /dev/null \
    && exit 0

exit 1
