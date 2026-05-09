#!/bin/bash

ssh -V > /dev/null 2>&1 \
    && exit 0
exit 1
