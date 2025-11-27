#!/bin/bash

# Select just lines containing 'inet'.
# 1.) Remove every indenting.
# 2.) Remove 'inet '.
# 3.) Remove everything after a '/' (including the /).
# Search each IP of the IPv4-list in file '/etc/hosts' 
# Select just lines containing 'managedHost'.
# 1.) Remove everything after a '#' (including the #).
# 2.) Remove every indenting.
# 3.) Remove blanks (spaces or tabs) at the end of lines.
# 4.) Replace blanks (spaces or tabs) with one ';' between the values.
# 5.) Delete empty lines.
# Then cut the second field
# Then cut the first field to get the short hostname
ip -4 addr \
    | grep 'inet' \
    | sed -e 's/^[[:blank:]]*//' \
        -e 's/inet //' \
        -e 's/\/.*//' \
    | xargs -i grep {} /etc/hosts \
    | grep 'managedHost' \
    | sed -e 's/#.*//' \
        -e 's/^[[:blank:]]*//' \
        -e 's/[[:blank:]]*$//' \
        -e 's/\s\+/;/g' \
        -e '/^$/d' \
    | cut -d';' -f2 \
    | cut -d'.' -f1

