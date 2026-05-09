#!/bin/bash

_CURRENT_APP='docker compose version'

${_CURRENT_APP} > /dev/null 2>&1 \
    && exit 0
exit 1
