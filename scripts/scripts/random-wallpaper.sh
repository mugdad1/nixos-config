#!/usr/bin/env bash

wallpaper_path="$HOME/Pictures/wallpapers"
wallpapers_folder="$HOME/Pictures/wallpapers/others"

current_wallpaper=$(readlink "$wallpaper_path/wallpaper" 2> /dev/null)
current_wallpaper_name="$(basename "$current_wallpaper")"

mapfile -t wallpaper_list < <(find -L "$wallpapers_folder" -type f \( -name '*.png' -o -name '*.jpg' -o -name '*.jpeg' \))
wallpaper_count=${#wallpaper_list[@]}
[ "$wallpaper_count" -eq 0 ] && exit 0

while true; do
    wallpaper_name="${wallpaper_list[RANDOM % wallpaper_count]}"

    if [[ "$wallpaper_name" != "$current_wallpaper" ]]; then
        break
    fi
done

ln -sf "$wallpaper_name" "$wallpaper_path/wallpaper"
wall-change "$wallpaper_path/wallpaper" &
