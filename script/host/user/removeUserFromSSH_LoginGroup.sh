#!/bin/bash

sudo usermod --remove --groups ssh_login "${1:?"Missing first parameter USER"}"
