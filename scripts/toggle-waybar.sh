#!/usr/bin/env bash
set -euo pipefail

SERVICE=".waybar-wrapped"

if pgrep -x "$SERVICE" > /dev/null; then
    pkill -9 waybar
else
    # Hyprland needs hyprland/workspaces, Sway needs sway/workspaces; the
    # session wrapper exports XDG_CURRENT_DESKTOP so both configs can coexist.
    if [[ ${XDG_CURRENT_DESKTOP:-} == *Hyprland* ]]; then
        runbg waybar -c "$HOME/.config/waybar/config-hypr"
    else
        runbg waybar
    fi
fi
