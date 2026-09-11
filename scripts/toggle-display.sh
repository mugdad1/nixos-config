#!/usr/bin/env bash
set -euo pipefail

MONITOR="eDP-1"
STATE_FILE="${XDG_RUNTIME_DIR:-/tmp}/toggle-display-spec"

if hyprctl monitors -j | jq -e --arg m "$MONITOR" 'any(.[]; .name == $m)' >/dev/null 2>&1; then
    hyprctl monitors -j | jq -r --arg m "$MONITOR" \
        '.[] | select(.name == $m) | "\(.width)x\(.height)@\(.refreshRate),\(.x)x\(.y),\(.scale)"' \
        >"$STATE_FILE"
    hyprctl keyword monitor "$MONITOR,disable"
else
    if [[ -f "$STATE_FILE" ]]; then
        SPEC="$(<"$STATE_FILE")"
    else
        SPEC="preferred,auto,1.2"
    fi
    hyprctl keyword monitor "$MONITOR,$SPEC"
fi