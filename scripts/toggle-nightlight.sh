#!/usr/bin/env bash
set -euo pipefail

LAT=24.7136
LON=46.6753
TEMPS=(4000 3000)

if [[ $# -eq 0 ]]; then
    echo "Usage: toggle-nightlight toggle | status" >&2
    exit 1
fi

if [[ $1 == "toggle" ]]; then
    if ! pgrep -x wlsunset > /dev/null; then
        wlsunset -l "$LAT" -L "$LON" -t "${TEMPS[0]}" > /dev/null 2>&1 &
    else
        OLD=$(ps -o args= -C wlsunset | grep -oP '(?<=-t )\d+' || true)
        pkill -x wlsunset
        sleep 0.5
        if [[ "$OLD" == "${TEMPS[0]}" ]]; then
            wlsunset -l "$LAT" -L "$LON" -t "${TEMPS[1]}" > /dev/null 2>&1 &
        fi
    fi
elif [[ $1 == "status" ]]; then
    if pgrep -x wlsunset > /dev/null; then
        TEMP=$(ps -o args= -C wlsunset | grep -oP '(?<=-t )\d+' || true)
        if [[ "$TEMP" == "3000" ]]; then
            printf '{"text": "󰛨", "class": "warmer", "alt": "3000K"}\n'
        else
            printf '{"text": "󰛨", "class": "active", "alt": "4000K"}\n'
        fi
    else
        printf '{"text": "󰛩", "class": "inactive", "alt": "off"}\n'
    fi
fi
