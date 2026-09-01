#!/usr/bin/env bash
set -euo pipefail
# Multi-engine web search via rofi

QUERY=$(rofi -dmenu -p "Search" -theme-str 'inputbar { children: [prompt, entry]; }')
[ -z "$QUERY" ] && exit 0

ENGINE=$(echo -e "DuckDuckGo\nNixOS Packages\nFreeTube" | rofi -dmenu -p "Engine" -theme-str 'inputbar { children: [prompt, entry]; }')
[ -z "$ENGINE" ] && exit 0

ENCODED=$(python3 -c "import urllib.parse, sys; print(urllib.parse.quote(sys.argv[1]))" "$QUERY")

case "$ENGINE" in
  "DuckDuckGo")    xdg-open "https://duckduckgo.com/?q=$ENCODED" ;;
  "NixOS Packages") xdg-open "https://search.nixos.org/packages?query=$ENCODED" ;;
  "FreeTube")        xdg-open "freetube://search/$ENCODED" ;;
esac
