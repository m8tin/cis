#!/bin/bash

getent group ssh_login > /dev/null \
    && exit 0
exit 1
