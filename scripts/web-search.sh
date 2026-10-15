#!/usr/bin/env bash
set -euo pipefail
# Multi-engine web search via rofi

QUERY=$(rofi -dmenu -p "Search" -theme-str 'inputbar { children: [prompt, entry]; }')
[ -z "$QUERY" ] && exit 0

# SearXNG first, DuckDuckGo second — mirrors the address bar default in
# modules/home/apps/browser.nix (his ask 2026-10-15: sear, not ddg).
ENGINE=$(echo -e "SearXNG\nDuckDuckGo\nNixOS Packages\nFreeTube" | rofi -dmenu -p "Engine" -theme-str 'inputbar { children: [prompt, entry]; }')
[ -z "$ENGINE" ] && exit 0

ENCODED=$(python3 -c "import urllib.parse, sys; print(urllib.parse.quote(sys.argv[1]))" "$QUERY")

case "$ENGINE" in
  "SearXNG")       xdg-open "http://100.88.29.31:8888/search?q=$ENCODED" ;;
  "DuckDuckGo")    xdg-open "https://duckduckgo.com/?q=$ENCODED" ;;
  "NixOS Packages") xdg-open "https://search.nixos.org/packages?query=$ENCODED" ;;
  "FreeTube")        freetube "https://www.youtube.com/results?search_query=$ENCODED" & ;;
esac
