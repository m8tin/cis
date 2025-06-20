#!/bin/bash

cat /sys/class/net/e*/address \
    | head -n 1
