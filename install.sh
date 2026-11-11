#!/usr/bin/env bash

set -euo pipefail

# tput fails on terminals with no terminfo entry (e.g. xterm-kitty over ssh),
# so fall back to raw ANSI.
RESET=$(tput sgr0 2> /dev/null || printf '\033[0m')
RED=$(tput setaf 1 2> /dev/null || printf '\033[31m')
GREEN=$(tput setaf 2 2> /dev/null || printf '\033[32m')
BLUE=$(tput setaf 4 2> /dev/null || printf '\033[34m')

OK="[${GREEN}OK${RESET}]\t"
INFO="[${BLUE}INFO${RESET}]\t"
ERROR="[${RED}ERROR${RESET}]\t"

if [[ $EUID -eq 0 ]]; then
    echo -e "${ERROR}Do not run as root!"
    exit 1
fi

if ! command -v whiptail &> /dev/null; then
    echo -e "${INFO}Installing whiptail..."
    nix-shell -p newt --run "$(realpath "$0")"
    exit $?
fi

# Detect the host from DMI. product_name alone is not enough on every box, so
# product_family is consulted too. Override with HOST=grandpa ./install.sh.
DMI_NAME="$(cat /sys/class/dmi/id/product_name 2> /dev/null || true)"
DMI_FAMILY="$(cat /sys/class/dmi/id/product_family 2> /dev/null || true)"

gpu_for() {
    case "$1" in
        victus) echo "nvidia" ;;
        t480s) echo "intel" ;;
        *) echo "none" ;;
    esac
}

if [ -n "${HOST:-}" ]; then
    GPU="$(gpu_for "$HOST")"
    echo -e "${INFO}Host forced by environment: ${GREEN}$HOST${RESET}"
elif grep -qi 't480s\|thinkpad\|20L8' <<< "$DMI_NAME"; then
    HOST="t480s"
    GPU="intel"
elif grep -qi 'victus\|hp' <<< "$DMI_NAME$DMI_FAMILY"; then
    HOST="victus"
    GPU="nvidia"
else
    # Unknown hardware defaults to the laptop, never the headless server.
    HOST="victus"
    GPU="nvidia"
    echo -e "${INFO}DMI named no known host; defaulting to ${GREEN}victus${RESET} (force with HOST=<host> ./install.sh)"
fi

CONFIG_USER="$(sed -n 's/.*username = "\([^"]*\)".*/\1/p' "hosts/${HOST}/variables.nix" 2> /dev/null | head -1)"
SUMMARY="\
Username:   ${CONFIG_USER:-unknown} (from variables.nix)
Host:       ${HOST:-unknown}
GPU:        ${GPU:-unknown}
DMI seen:   name='${DMI_NAME:-}' family='${DMI_FAMILY:-}'"

if ! (whiptail --yesno "$SUMMARY\n\nProceed with installation?" 12 40 --title "NixOS Installer"); then
    exit 0
fi

# variables.nix is the source of truth; `whoami` is "nixos" on the live ISO.
TARGET_USER="${TARGET_USER:-}"
if [ -n "$TARGET_USER" ]; then
    echo -e "${INFO}Overriding username to ${GREEN}$TARGET_USER${RESET}"
    sed -i -e "s/username = \"[^\"]*\"/username = \"$TARGET_USER\"/" "hosts/${HOST}/variables.nix"
else
    echo -e "${INFO}Using username from hosts/${HOST}/variables.nix"
fi

echo -e "${INFO}Preparing environment"
mkdir -p ~/Music ~/Documents ~/Pictures/wallpapers/others
ln -sf "$PWD/assets/wallpapers/wallpaper.png" ~/Pictures/wallpapers/wallpaper 2> /dev/null || true

# sops is grandpa-only, and the private key is the one thing a declarative
# system cannot restore. Refuse to build a system that cannot activate.
if [ "$HOST" = "grandpa" ] && [ ! -f /var/lib/sops-nix/key.txt ]; then
    KEY_SRC=""
    for candidate in "$HOME/age-key.txt" "./age-key.txt"; do
        if [ -f "$candidate" ]; then
            KEY_SRC="$candidate"
            break
        fi
    done
    if [ -n "$KEY_SRC" ]; then
        echo -e "${INFO}Installing sops age key from ${KEY_SRC}"
        sudo install -D -m 600 -o root -g root "$KEY_SRC" /var/lib/sops-nix/key.txt
    else
        echo -e "${ERROR}No sops age key found."
        echo -e "${INFO}Put it at /var/lib/sops-nix/key.txt (or ~/age-key.txt) and re-run; see README, 'sops secrets'."
        exit 1
    fi
fi

if [ ! -f /etc/nixos/hardware-configuration.nix ]; then
    echo -e "${ERROR}/etc/nixos/hardware-configuration.nix not found! Aborting."
    exit 1
fi
cp /etc/nixos/hardware-configuration.nix "hosts/${HOST}/hardware-configuration.nix"

echo -e "${INFO}Starting system build..."
sudo nixos-rebuild switch --flake ."#${HOST}"

echo -e "${OK}Done! Reboot to apply."
