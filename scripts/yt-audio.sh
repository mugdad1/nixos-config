#!/usr/bin/env bash
set -euo pipefail

URL=$(rofi -dmenu -p "YouTube URL" -theme-str 'inputbar { children: [prompt, entry]; }')
[ -z "$URL" ] && exit 0

yt-dlp -f "bestaudio" -o - "$URL" 2>/dev/null \
  | ffplay -nodisp -autoexit -fflags nobuffer -flags low_delay -framedrop -probesize 32 -analyzeduration 0 pipe:0 2>/dev/null
