#!/usr/bin/env bash

DISPLAYS=("eDP-1" "eDP-2")

for DISPLAY in "${DISPLAYS[@]}"; do
    if hyprctl monitors | grep -q "^Monitor $DISPLAY"; then
        hyprctl keyword monitor "$DISPLAY,disable"
    else
        hyprctl keyword monitor "$DISPLAY,1920x1080@60,0x0,1.2"
    fi
done
