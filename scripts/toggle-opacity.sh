#!/usr/bin/env bash
set -euo pipefail
# Toggle transparency of the currently focused window
read -r addr current <<< "$(hyprctl activewindow -j | jq -r '"\(.address) \(.alpha)"')"

if [ "$current" = "1" ] || [ "$current" = "1.0" ] || [ -z "$current" ]; then
  hyprctl dispatch setprop address "$addr" alpha 0.85
else
  hyprctl dispatch setprop address "$addr" alpha 1.0
fi
