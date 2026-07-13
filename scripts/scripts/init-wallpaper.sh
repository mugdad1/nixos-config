#!/usr/bin/env bash

# Start awww daemon if not running
if ! pgrep -x awww-daemon > /dev/null; then
    awww-daemon --no-cache &

    # Wait until the daemon is ready
    while ! awww query > /dev/null 2>&1; do
        sleep 0.1
    done
fi

# Ensure a wallpaper symlink exists (first boot), then set it
WP="$HOME/Pictures/wallpapers/wallpaper"
if [ ! -e "$WP" ]; then
  WP_DEFAULT=$(find -L "$HOME/Pictures/wallpapers/others" -type f \( -name '*.png' -o -name '*.jpg' \) | head -1)
  [ -n "$WP_DEFAULT" ] && ln -sf "$WP_DEFAULT" "$WP"
fi

# Set wallpaper
awww img -t none "$WP" &
