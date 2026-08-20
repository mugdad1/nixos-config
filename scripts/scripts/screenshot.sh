#!/usr/bin/env bash
set -euo pipefail

dir="$HOME/Pictures/Screenshots"
time=$(date +'%Y_%m_%d_at_%Hh%Mm%Ss')
file="${dir}/Screenshot_${time}.png"

copy() {
    grimblast --notify --freeze copy area
}

save() {
    grimblast --notify --freeze save area "$file"
}

swappy_() {
    grimblast --notify --freeze save area "$file"
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
    copy
elif [[ "$1" == "--save" ]]; then
    save
elif [[ "$1" == "--swappy" ]]; then
    swappy_
else
    echo "Unknown option: $1" >&2
    echo "Usage: screenshot --copy | --save | --swappy" >&2
    exit 1
fi
