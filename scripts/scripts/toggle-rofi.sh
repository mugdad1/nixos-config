#!/usr/bin/env bash
set -euo pipefail

if pgrep -x rofi > /dev/null; then
    pkill rofi
else
    eval "$@"
fi
