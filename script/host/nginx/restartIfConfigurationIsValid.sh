#!/bin/bash

nginx -t &> /dev/null \
    && systemctl restart nginx.service \
    && exit 0

exit 1
