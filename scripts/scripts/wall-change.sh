#!/usr/bin/env bash
set -euo pipefail

animations=("outer" "center" "any" "wipe")
random_animation=${animations[RANDOM % ${#animations[@]}]}

if [[ "$random_animation" == "wipe" ]]; then
    awww img --transition-type="wipe" --transition-angle=135 $1 &
else
    awww img --transition-type="$random_animation" $1 &
fi
