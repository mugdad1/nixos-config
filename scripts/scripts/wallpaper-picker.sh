#!/usr/bin/env bash
set -e

wallpaper_path=$HOME/Pictures/wallpapers
wallpapers_folder=$HOME/Pictures/wallpapers/others

mapfile -t wallpapers < <(cd "$wallpapers_folder" && find -L . -type f \( -name '*.png' -o -name '*.jpg' -o -name '*.jpeg' \) | sed 's|^\./||')
[ "${#wallpapers[@]}" -eq 0 ] && exit 0

chosen="$(printf '%s\n' "${wallpapers[@]}" | rofi -dmenu || pkill rofi)"
[ -z "$chosen" ] && exit 0

full="$wallpapers_folder/$chosen"
if [[ -f $full ]]; then
    ln -sf "$full" "$wallpaper_path/wallpaper"
    wall-change "$wallpaper_path/wallpaper"
else
    exit 1
fi
