#!/bin/bash

zfs --version > /dev/null 2>&1 \
    && exit 0
exit 1
