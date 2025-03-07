#!/bin/bash

_URL="${1:?"URL of site missing"}"

#curl:
# --connect-timeout SECONDS  Maximum time allowed for connection
# -k                         Allow connections to SSL sites without certs (H)
# -L                         Follow redirects (H)
# --max-time        SECONDS  Maximum time allowed for the transfer
# -s                         Silent mode. Don't output anything
# --head                     Show head information only
# --no-progress-meter        Clean output for grep

#grep:
# -q                         Quite, no output just status codes
# -F                         Interpret search term as plain text
((curl --connect-timeout 10 --max-time 10 -k -s --head --no-progress-meter "${_URL}" | grep -qF '200 OK') && echo OK) || echo FAIL
