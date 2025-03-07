#!/bin/bash

SERVER="${1:?"FQDN of server missing"}"
FILE="pool-size.txt"

# --connect-timeout SECONDS  Maximum time allowed for connection
# -k                         Allow connections to SSL sites without certs (H)
# -L                         Follow redirects (H)
# --max-time        SECONDS  Maximum time allowed for the transfer
# -s                         Silent mode. Don't output anything
# -f                         Fail fast with no output on HTTP errors (otherwise no exit-code > 0 on 404)
RESULT="$(curl --connect-timeout 10 --max-time 10 -k -s -f https://$SERVER/monitoring/$FILE || echo WARN#404 on $FILE check HTTPS)"
echo $RESULT
