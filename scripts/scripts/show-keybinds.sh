#!/usr/bin/env bash

config_file=~/.config/hypr/hyprland.conf
mod=$(grep '^\$mod\s*=' "$config_file" | head -1 | sed 's/.*=\s*//; s/[" ]//g')

if [ -z "$mod" ]; then
    mod="SUPER"
fi

keybinds=$(grep -E '^\s*bind\s*=' "$config_file" | sed "s/.*=\s*//; s/\$mod/$mod/g; s/^,\s*/  /")

if pgrep -x rofi > /dev/null; then
    pkill rofi
else
    rofi -dmenu -theme-str 'window {width: 50%;} listview {columns: 1;}' -p "Keybinds" <<< "$keybinds"
fi
