#!/usr/bin/env bash
# Multi-engine web search via rofi

QUERY=$(rofi -dmenu -p "Search" -theme-str 'inputbar { children: [prompt, entry]; }')
[ -z "$QUERY" ] && exit 0

ENGINE=$(echo -e "DuckDuckGo\nNixOS Packages\nYouTube" | rofi -dmenu -p "Engine" -theme-str 'inputbar { children: [prompt, entry]; }')
[ -z "$ENGINE" ] && exit 0

ENCODED=$(python3 -c "import urllib.parse; print(urllib.parse.quote('$QUERY'))")

case "$ENGINE" in
  "DuckDuckGo")    xdg-open "https://duckduckgo.com/?q=$ENCODED" ;;
  "NixOS Packages") xdg-open "https://search.nixos.org/packages?query=$ENCODED" ;;
  "YouTube")        xdg-open "https://www.youtube.com/results?search_query=$ENCODED" ;;
esac
