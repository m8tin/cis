#/bin/bash

[ "$(apt-get -s -o Debug::NoLocking=true upgrade | grep -c -E '^Inst')" = "0" ] \
    && exit 0

exit 1
