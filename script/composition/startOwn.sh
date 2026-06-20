#!/bin/bash
source /cis/core/base.module.sh
base.loadModule composition



function startOwn() {
    local _COMPOSITION
    composition.printAll | while read -r _COMPOSITION; do
        composition.start "${_COMPOSITION}"
    done
}

startOwn && exit 0
exit 1
