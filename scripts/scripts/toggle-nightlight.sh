#!/usr/bin/env bash

TEMPS=(4000 3000)

if [[ $1 == "toggle" ]]; then
    if ! pgrep -x hyprsunset > /dev/null; then
        hyprsunset -t "${TEMPS[0]}" > /dev/null 2>&1 &
    else
        OLD=$(ps -o args= -C hyprsunset | grep -oP '(?<=-t )\d+')
        pkill -x hyprsunset
        sleep 0.5
        if [[ "$OLD" == "${TEMPS[0]}" ]]; then
            hyprsunset -t "${TEMPS[1]}" > /dev/null 2>&1 &
        fi
    fi
elif [[ $1 == "status" ]] || [[ -z $1 ]]; then
    if pgrep -x hyprsunset > /dev/null; then
        TEMP=$(ps -o args= -C hyprsunset | grep -oP '(?<=-t )\d+')
        if [[ "$TEMP" == "3000" ]]; then
            printf '{"text": "󰛨", "class": "warmer", "alt": "3000K"}\n'
        else
            printf '{"text": "󰛨", "class": "active", "alt": "4000K"}\n'
        fi
    else
        printf '{"text": "󰛩", "class": "inactive", "alt": "off"}\n'
    fi
fi
