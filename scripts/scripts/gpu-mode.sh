#!/usr/bin/env bash

current=$(supergfxctl -g)
modes=$(supergfxctl -s | tr -d '[]')

chosen=$(echo "$modes" | fzf --prompt="GPU mode (current: $current) > " --height=10)

if [ -n "$chosen" ]; then
    supergfxctl -m "$chosen"
    notify-send "GPU Mode" "Switched to $chosen — logout/reboot to apply"
fi
