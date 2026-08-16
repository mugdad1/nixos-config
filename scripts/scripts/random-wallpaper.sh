#!/usr/bin/env bash
set -euo pipefail

wallpaper_path="$HOME/Pictures/wallpapers"
wallpapers_folder="$HOME/Pictures/wallpapers/others"

if ! command -v fd > /dev/null 2>&1 || ! fd -L --base-directory "$wallpapers_folder" -d 1 -t f -q; then
    echo "no wallpapers in $wallpapers_folder" >&2
    exit 1
fi

mapfile -t wallpaper_list < <(fd -L --base-directory "$wallpapers_folder" -d 1 -t f)
wallpaper_count=${#wallpaper_list[@]}
[ "$wallpaper_count" -eq 0 ] && exit 1

current_wallpaper="$(readlink "$wallpaper_path/wallpaper" 2> /dev/null || true)"
current_name="$(basename "${current_wallpaper:-}")"

candidate="${wallpaper_list[RANDOM % wallpaper_count]}"
for _ in $(seq 1 50); do
    if [[ "$candidate" != "$current_name" ]]; then
        break
    fi
    candidate="${wallpaper_list[RANDOM % wallpaper_count]}"
done

ln -sf "$wallpapers_folder/$candidate" "$wallpaper_path/wallpaper"
wall-change "$wallpaper_path/wallpaper" &
