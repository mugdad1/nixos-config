#!/usr/bin/env bash
set -euo pipefail

command_window_address=$(hyprctl activewindow -j | jq -r '.address')

focus() {
    hyprctl dispatch focuswindow "address:$command_window_address" > /dev/null
}

start_time=$(date +%s)

"$@" || exit_status=$?
exit_status=${exit_status:-0}

end_time=$(date +%s)
duration=$(($end_time - $start_time))
duration_formatted="$((duration / 60))m $(printf "%02d" $((duration % 60)))s"

active_window_address=$(hyprctl activewindow -j | jq -r '.address')

if [ "$active_window_address" != "$command_window_address" ]; then
    if [ $exit_status -ne 0 ]; then
        action=$(
            notify-send -u critical \
                --action="focus=focus" \
                "NixOS Flake" \
                "\'$*\' failed after $duration_formatted" 2> /dev/null
        )

        [ "$action" = "focus" ] && focus
    else
        notify-send -u normal \
            "NixOS Flake" \
            "\'$*\' succeeded after $duration_formatted" 2> /dev/null
    fi
fi

if [ $exit_status -ne 0 ]; then
    exit 1
fi
