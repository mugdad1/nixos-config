#!/usr/bin/env bash

red='#cc241d'
green='#98971a'
yellow='#d79921'

power_saver="<span color='${green}'>󰾆 </span>"
balanced="<span color='${yellow}'>󰾅 </span>"
performance="<span color='${red}'>󰓅 </span>"

state_file="/var/lib/gpu-mode/state"

current_gpu=$(supergfxctl -g)
current_cpu=$(powerprofilesctl get)

selected_row=0
if [ "$current_gpu" = "AsusMuxDgpu" ] || [ "$current_cpu" = "performance" ]; then
    selected_row=2
elif [ "$current_gpu" = "Hybrid" ] || [ "$current_cpu" = "balanced" ]; then
    selected_row=1
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

unlock_mux_and_switch() {
    local target="$1"
    pkexec sh -c "
        sed -i 's/gpu_mux_mode: 1/gpu_mux_mode: 0/' /etc/asusd/asusd.ron 2>/dev/null
        systemctl restart asusd 2>/dev/null || true
        supergfxctl -m '$target'
        mkdir -p $(dirname "$state_file")
        echo '$target' > '$state_file'
    "
}

run_cmd() {
    local gpu_mode="$1"
    local cpu_mode="$2"
    local label="$3"

    powerprofilesctl set "$cpu_mode"

    if [ "$current_gpu" = "AsusMuxDgpu" ] && [ "$gpu_mode" != "AsusMuxDgpu" ]; then
        unlock_mux_and_switch "$gpu_mode"
        notify-send -u critical "Profile" "$label — REBOOT to fully apply"
    else
        if pkexec sh -c "supergfxctl -m '$gpu_mode' && mkdir -p $(dirname "$state_file") && echo '$gpu_mode' > '$state_file'"; then
            notify-send -u normal "Profile" "$label"
        fi
    fi
}

chosen=$(run_rofi)
case $chosen in
    $performance)
        run_cmd "AsusMuxDgpu" "performance" "Performance — NVIDIA only (REBOOT required)"
        ;;
    $balanced)
        run_cmd "Hybrid" "balanced" "Balanced — Both GPUs (logout to apply)"
        ;;
    $power_saver)
        run_cmd "Integrated" "power-saver" "Power Saving — AMD only (logout to apply)"
        ;;
esac
