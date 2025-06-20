#!/bin/bash

sudo usermod --append --groups sudo "${1:?"Missing first parameter USER"}"
