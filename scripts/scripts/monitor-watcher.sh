#!/usr/bin/env bash

# based on https://github.com/ash-17/omarchy-external-monitor/tree/d06a323e7fb39d73be3955b94305830bfdc4a74a

restart-apps() {
    # restart wallpaper
    pkill .awww-daemon-wr 2> /dev/null
    init-wallpaper &

    # restart waybar
    pkill .waybar-wrapped 2> /dev/null
    waybar &

    # restart swayosd (crashes on monitor change)
    pkill .swayosd-server 2> /dev/null
    swayosd-server &
}

handle-monitor-state() {
    # detect external monitors (HDMI-* or DP-*)
    external_present=$(hyprctl monitors | grep -E "^Monitor (HDMI-|DP-)" || true)

    # count enabled monitors
    enabled_count=$(hyprctl monitors | grep -c "^Monitor")

    # is an external monitor connected
    if [ -n "$external_present" ]; then

        # only disable internal displays if more than 1 monitor is active
        if [ "$enabled_count" -gt 1 ]; then
            for disp in eDP-1 eDP-2; do
                hyprctl keyword monitor "$disp,disable"
            done
        fi
    else
        # no external monitor - enable laptop screens
        for disp in eDP-1 eDP-2; do
            hyprctl keyword monitor "$disp,1920x1080@60,0x0,1"
        done
    fi
}

# --- startup check --- #
sleep 1

handle-monitor-state
restart-apps

# --- hyprland events listener --- #
socat -U - UNIX-CONNECT:"$XDG_RUNTIME_DIR/hypr/$HYPRLAND_INSTANCE_SIGNATURE/.socket2.sock" |
    while read -r line; do
        # react on external monitor plug/unplug or hyprland reload
        if echo "$line" | grep -qE "monitor(added|removed)>>(HDMI-|DP-)|configreloaded"; then
            handle-monitor-state
            restart-apps
        fi
    done
