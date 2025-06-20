#!/bin/bash

sudo usermod --remove --groups sudo "${1:?"Missing first parameter USER"}"
