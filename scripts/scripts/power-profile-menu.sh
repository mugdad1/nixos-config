#!/usr/bin/env bash
set -euo pipefail

red='#cc241d'
green='#98971a'
yellow='#d79921'

power_saver="<span color='${green}'>󰾆 </span>"
balanced="<span color='${yellow}'>󰾅 </span>"
performance="<span color='${red}'>󰓅 </span>"

mux=$(cat /sys/devices/platform/asus-nb-wmi/gpu_mux_mode 2> /dev/null)

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

HELPER=/run/wrappers/bin/power-profile-helper

run_gpu_cmd() {
    local action="$1"
    local cpu_mode="$2"
    local label="$3"

    profile="${cpu_mode/power-saver/quiet}"
    asusctl profile set -a "$profile"
    asusctl profile set -b "$profile"

    case $action in
        amd-only)
            $HELPER desired-mode amd
            $HELPER cardwire-set integrated
            if [ "$mux" != "1" ]; then
                $HELPER mux 1
                notify-send -u normal "Profile" "AMD Only — MUX flipped to Optimus. Rebooting..."
                sleep 2 && systemctl reboot
            fi
            ;;
        nvidia-only)
            # cardwire v0.12+ refuses manual mode while the iGPU is live
            # (Laptop classification). Persist the intent + flip the MUX to
            # dGPU, then reboot: in dGPU mode the system classifies as Desktop
            # and cardwire-apply-blocks applies manual + blocks AMD at boot.
            $HELPER desired-mode nvidia
            if [ "$mux" != "0" ]; then
                $HELPER mux 0
                notify-send -u normal "Profile" "NVIDIA Only — MUX flipped to dGPU. Rebooting..."
                sleep 2 && systemctl reboot
            fi
            ;;
        hybrid)
            $HELPER desired-mode hybrid
            $HELPER cardwire-set hybrid
            if [ "$mux" != "1" ]; then
                $HELPER mux 1
            fi
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
