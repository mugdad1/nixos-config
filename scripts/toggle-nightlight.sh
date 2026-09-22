#!/usr/bin/env bash
set -euo pipefail

LAT=24.7136
LON=46.6753
TEMPS=(4000 2000)

if [[ $# -eq 0 ]]; then
    echo "Usage: toggle-nightlight toggle | status" >&2
    exit 1
fi

if [[ $1 == "toggle" ]]; then
    if ! pgrep -x wlsunset > /dev/null; then
        nohup wlsunset -l "$LAT" -L "$LON" -t "${TEMPS[0]}" > /dev/null 2>&1 &
    else
        OLD=$(ps -o args= -C wlsunset | grep -oP '(?<=-t )\d+' || true)
        pkill -x wlsunset || true
        # wlroots fails a new client while an existing gamma control for the
        # output remains, so wait for the old instance to actually release it.
        for _ in $(seq 1 50); do
            pgrep -x wlsunset > /dev/null || break
            sleep 0.1
        done
        if [[ "$OLD" == "${TEMPS[0]}" ]]; then
            nohup wlsunset -l "$LAT" -L "$LON" -t "${TEMPS[1]}" > /dev/null 2>&1 &
        fi
    fi
elif [[ $1 == "status" ]]; then
    if pgrep -x wlsunset > /dev/null; then
        TEMP=$(ps -o args= -C wlsunset | grep -oP '(?<=-t )\d+' || true)
        if [[ "$TEMP" == "2000" ]]; then
            printf '{"text": "󰛨", "class": "warmer", "alt": "2000K"}\n'
        else
            printf '{"text": "󰛨", "class": "active", "alt": "4000K"}\n'
        fi
    else
        printf '{"text": "󰛩", "class": "inactive", "alt": "off"}\n'
    fi
fi
