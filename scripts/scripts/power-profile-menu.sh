#!/usr/bin/env bash

red='#cc241d'
green='#98971a'
yellow='#d79921'

power_saver="<span color='${green}'>󰾆 </span>"
balanced="<span color='${yellow}'>󰾅 </span>"
performance="<span color='${red}'>󰓅 </span>"

current_cpu=$(powerprofilesctl get)
mux=$(cat /sys/devices/platform/asus-nb-wmi/gpu_mux_mode 2>/dev/null)

selected_row=0
case $current_cpu in
    performance) selected_row=2 ;;
    balanced)    selected_row=1 ;;
esac

current_gpu=$(cardwire get 2>/dev/null)
case $current_gpu in
    Integrated) selected_row=0 ;;
    Hybrid)     selected_row=1 ;;
    Manual)     selected_row=2 ;;
esac

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

run_gpu_cmd() {
    local action="$1"
    local cpu_mode="$2"
    local label="$3"

    powerprofilesctl set "$cpu_mode"

    case $action in
        amd-only)
            pkexec cardwire set integrated
            if [ "$mux" != "1" ]; then
                pkexec bash -c 'echo 1 > /sys/devices/platform/asus-nb-wmi/gpu_mux_mode'
                notify-send -u critical "Profile" "AMD Only — MUX flipped to Optimus. Rebooting..."
                sleep 2 && systemctl reboot
            fi
            ;;
        nvidia-only)
            pkexec cardwire set manual
            pkexec cardwire gpu 1 --block
            if [ "$mux" != "0" ]; then
                pkexec bash -c 'echo 0 > /sys/devices/platform/asus-nb-wmi/gpu_mux_mode'
                notify-send -u critical "Profile" "NVIDIA Only — MUX flipped to dGPU. Rebooting..."
                sleep 2 && systemctl reboot
            fi
            ;;
        hybrid)
            pkexec cardwire set hybrid
            ;;
    esac

    notify-send -u normal "Profile" "$label"
}

chosen=$(run_rofi)
case $chosen in
    $performance)
        run_gpu_cmd "nvidia-only" "performance" "Performance — NVIDIA only"
        ;;
    $balanced)
        run_gpu_cmd "hybrid" "balanced" "Balanced — Both GPUs"
        ;;
    $power_saver)
        run_gpu_cmd "amd-only" "power-saver" "Power Saving — AMD only"
        ;;
esac
