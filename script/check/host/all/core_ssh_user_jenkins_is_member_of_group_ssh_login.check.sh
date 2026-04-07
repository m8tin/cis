#!/bin/bash

getent group ssh_login | grep -q jenkins \
    && exit 0
exit 1
