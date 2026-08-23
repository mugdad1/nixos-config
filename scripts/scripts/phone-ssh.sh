#!/usr/bin/env bash
set -euo pipefail

PHONE_IP="${1:-}"

if [[ -z "$PHONE_IP" ]]; then
  PHONE_IP=$(adb shell "ip -4 addr show wlan0 2>/dev/null" \
    | grep -oE 'inet [0-9.]+' | awk '{print $2}' | head -1 || true)
fi

if [[ -n "$PHONE_IP" ]] && ping -c1 -W1 "$PHONE_IP" >/dev/null 2>&1; then
  sed -i "s/HostName .*/HostName $PHONE_IP/" "$HOME/.ssh/config"
fi

if ! ssh -o ConnectTimeout=4 phone true 2>/dev/null; then
  echo "[phone] lan unreachable, falling back to usb adb forward"
  adb forward tcp:8022 tcp:8022 >/dev/null
  if ! grep -q "^Host phone-usbfwd$" "$HOME/.ssh/config" 2>/dev/null; then
    printf '\nHost phone-usbfwd\n    HostName 127.0.0.1\n    Port 8022\n' >>"$HOME/.ssh/config"
  fi
  exec ssh phone-usbfwd
fi

exec ssh phone
