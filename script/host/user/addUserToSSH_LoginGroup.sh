#!/bin/bash

sudo usermod --append --groups ssh_login "${1:?"Missing first parameter USER"}"
