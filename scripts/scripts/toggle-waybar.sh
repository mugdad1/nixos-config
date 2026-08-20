#!/usr/bin/env bash
set -euo pipefail

SERVICE=".waybar-wrapped"

if pgrep -x "$SERVICE" > /dev/null; then
    pkill -9 waybar
else
    runbg waybar
fi
