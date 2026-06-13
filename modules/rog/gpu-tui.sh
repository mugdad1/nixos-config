#!/bin/bash

while true; do
  mux=$(cat /sys/devices/platform/asus-nb-wmi/gpu_mux_mode 2>/dev/null)
  choice=$(dialog --clear --title "GPU Mode Switcher" \
    --menu "Pick a mode:" 11 45 4 \
    "1" "AMD Only (disables NVIDIA)" \
    "2" "NVIDIA Only (disables AMD)" \
    "3" "Both" \
    "4" "Exit" \
    2>&1 >/dev/tty)

  case $choice in
    1)
      pkexec cardwire set integrated
      if [ "$mux" != "1" ]; then
        pkexec bash -c 'echo 1 > /sys/devices/platform/asus-nb-wmi/gpu_mux_mode' 2>/dev/null
        powerprofilesctl set power-saver
        dialog --msgbox "AMD Only set.\nMUX flipped to Optimus. Rebooting..." 6 40
        sleep 2
        systemctl reboot
      else
        dialog --msgbox "AMD Only active.\nAlready in Optimus mode." 5 40
      fi
      ;;
    2)
      pkexec cardwire set manual
      pkexec cardwire gpu 1 --block
      if [ "$mux" != "0" ]; then
        pkexec bash -c 'echo 0 > /sys/devices/platform/asus-nb-wmi/gpu_mux_mode' 2>/dev/null
        powerprofilesctl set performance
        dialog --msgbox "NVIDIA Only set.\nMUX flipped to dGPU. Rebooting..." 6 40
        sleep 2
        systemctl reboot
      else
        dialog --msgbox "NVIDIA Only active.\nAMD is blocked." 6 40
      fi
      ;;
    3)
      pkexec cardwire set hybrid
      powerprofilesctl set balanced
      dialog --msgbox "Hybrid mode active." 5 30
      ;;
    4)
      clear
      exit 0
      ;;
  esac
done
