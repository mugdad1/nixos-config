#!/usr/bin/env bash
set -euo pipefail

wallpaper_path=$HOME/Pictures/wallpapers
wallpapers_folder=$HOME/Pictures/wallpapers/others

wallpaper_name="$(fd -L --base-directory "$wallpapers_folder" -d 1 -t f | rofi -dmenu || pkill rofi || true)"

if [[ -n "$wallpaper_name" && -e "$wallpapers_folder/$wallpaper_name" ]]; then
    ln -sf "$wallpapers_folder/$wallpaper_name" "$wallpaper_path/wallpaper"
    wall-change "$wallpaper_path/wallpaper"
fi
