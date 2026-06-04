#!/usr/bin/env bash

red='#cc241d'
green='#98971a'
yellow='#d79921'

power_saver="<span color='${green}'>󰾆 </span>"
balanced="<span color='${yellow}'>󰾅 </span>"
performance="<span color='${red}'>󰓅 </span>"

current_cpu=$(powerprofilesctl get)
has_gpu=$(command -v supergfxctl)

selected_row=0
case $current_cpu in
    performance) selected_row=2 ;;
    balanced)    selected_row=1 ;;
esac

if [ -n "$has_gpu" ]; then
    current_gpu=$(supergfxctl -g 2>/dev/null)
    case $current_gpu in
        AsusMuxDgpu|AsusMux*) selected_row=2 ;;
        Hybrid)               selected_row=1 ;;
    esac
fi

theme="$HOME/.config/rofi/powermenu-theme.rasi"

rofi_cmd() {
    rofi -theme-str 'window {width: 300px;}' \
        -theme-str 'listview { columns: 3; }' \
        -selected-row ${selected_row} \
        -dmenu -theme "${theme}" -markup-rows
}

run_rofi() {
    echo -e "${power_saver}\n${balanced}\n${performance}" | rofi_cmd
}

run_cmd() {
    local cpu_mode="$1"
    local label="$2"

    powerprofilesctl set "$cpu_mode"
    notify-send -u normal "Profile" "$label"
}

run_cmd_gpu() {
    local gpu_mode="$1"
    local cpu_mode="$2"
    local label="$3"

    powerprofilesctl set "$cpu_mode"
    sudo sh -c "
        sed -i 's/\"mode\":.*/\"mode\": \"$gpu_mode\",/' /etc/supergfxd.conf
        supergfxctl -m '$gpu_mode'
    "
    notify-send -u normal "Profile" "$label"
}

chosen=$(run_rofi)
if [ -n "$has_gpu" ]; then
    case $chosen in
        $performance)
            run_cmd_gpu "AsusMuxDgpu" "performance" "Performance — NVIDIA only (REBOOT to apply)"
            ;;
        $balanced)
            run_cmd_gpu "Hybrid" "balanced" "Balanced — Both GPUs"
            ;;
        $power_saver)
            run_cmd_gpu "Integrated" "power-saver" "Power Saving — AMD only"
            ;;
    esac
else
    case $chosen in
        $performance)
            run_cmd "performance" "Performance"
            ;;
        $balanced)
            run_cmd "balanced" "Balanced"
            ;;
        $power_saver)
            run_cmd "power-saver" "Power Saving"
            ;;
    esac
fi
