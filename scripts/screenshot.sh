#!/usr/bin/env bash
set -euo pipefail

dir="$HOME/Pictures/Screenshots"
time=$(date +'%Y_%m_%d_at_%Hh%Mm%Ss')
file="${dir}/Screenshot_${time}.png"

notify() {
    notify-send -a screenshot "Screenshot saved to $1"
}

copy_area() {
    out=$(slurp)
    grim -g "$out" - | wl-copy -t image/png
}

save_screen() {
    grim "$file"
    notify "$file"
}

save_area() {
    out=$(slurp)
    grim -g "$out" "$file"
    notify "$file"
}

swappy_() {
    out=$(slurp)
    grim -g "$out" "$file"
    swappy -f "$file"
}

if [[ ! -d "$dir" ]]; then
    mkdir -p "$dir"
fi

if [[ $# -eq 0 ]]; then
    echo "Usage: screenshot --copy | --save | --swappy" >&2
    exit 1
fi

if [[ "$1" == "--copy" ]]; then
    copy_area
elif [[ "$1" == "--save" ]]; then
    save_screen
elif [[ "$1" == "--swappy" ]]; then
    swappy_
else
    echo "Unknown option: $1" >&2
    echo "Usage: screenshot --copy | --save | --swappy" >&2
    exit 1
fi