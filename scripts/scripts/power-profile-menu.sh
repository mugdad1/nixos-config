#!/usr/bin/env bash

red='#cc241d'
green='#98971a'
yellow='#d79921'

power_saver="<span color='${green}'>󰾆 </span>"
balanced="<span color='${yellow}'>󰾅 </span>"
performance="<span color='${red}'>󰓅 </span>"

mux=$(cat /sys/devices/platform/asus-nb-wmi/gpu_mux_mode 2> /dev/null)

amd_pci="0000:05:00.0"
nvidia_pci="0000:01:00.0"

amd_id=$(cardwire list --json 2> /dev/null | jq -r "to_entries[] | select(.value.pci == \"$amd_pci\") | .value.id")
nvidia_id=$(cardwire list --json 2> /dev/null | jq -r "to_entries[] | select(.value.pci == \"$nvidia_pci\") | .value.id")

current_gpu=$(cardwire get 2> /dev/null | xargs)
case $current_gpu in
    Integrated) selected_row=0 ;;
    Hybrid) selected_row=1 ;;
    Manual) selected_row=2 ;;
    *) selected_row=0 ;;
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

run_gpu_cmd() {
    local action="$1"
    local cpu_mode="$2"
    local label="$3"

    profile="${cpu_mode/power-saver/quiet}"
    asusctl profile set -a "$profile"
    asusctl profile set -b "$profile"

    case $action in
        amd-only)
            pkexec env PATH="$PATH" cardwire set manual
            [ -n "$nvidia_id" ] && pkexec env PATH="$PATH" cardwire gpu "$nvidia_id" --block
            if [ "$mux" != "1" ]; then
                pkexec env PATH="$PATH" bash -c 'echo 1 > /sys/devices/platform/asus-nb-wmi/gpu_mux_mode'
                notify-send -u critical "Profile" "AMD Only — MUX flipped to Optimus. Rebooting..."
                sleep 2 && systemctl reboot
            fi
            ;;
        nvidia-only)
            pkexec env PATH="$PATH" cardwire set manual
            [ -n "$amd_id" ] && pkexec env PATH="$PATH" cardwire gpu "$amd_id" --block
            if [ "$mux" != "0" ]; then
                pkexec env PATH="$PATH" bash -c 'echo 0 > /sys/devices/platform/asus-nb-wmi/gpu_mux_mode'
                notify-send -u critical "Profile" "NVIDIA Only — MUX flipped to dGPU. Rebooting..."
                sleep 2 && systemctl reboot
            fi
            ;;
        hybrid)
            pkexec env PATH="$PATH" cardwire set hybrid
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
