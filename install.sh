#!/usr/bin/env bash

set -euo pipefail

CURRENT_USERNAME=$(whoami)

# Colour setup. These used to be bare `tput` calls, which meant the installer
# died instantly over ssh from kitty or ghostty: those set TERM=xterm-kitty /
# xterm-ghostty, a fresh box has no terminfo entry for either, tput exits
# non-zero, and `set -e` above aborts before a single line of output. The
# terminal itself still renders plain ANSI regardless of terminfo, so the
# fallback is the raw escape sequence — colour keeps working, and the script
# no longer depends on the terminfo database being present.
RESET=$(tput sgr0 2>/dev/null || printf '\033[0m')
RED=$(tput setaf 1 2>/dev/null || printf '\033[31m')
GREEN=$(tput setaf 2 2>/dev/null || printf '\033[32m')
BLUE=$(tput setaf 4 2>/dev/null || printf '\033[34m')

OK="[${GREEN}OK${RESET}]\t"
INFO="[${BLUE}INFO${RESET}]\t"
ERROR="[${RED}ERROR${RESET}]\t"

#--- Root check ---#

if [[ $EUID -eq 0 ]]; then
    echo -e "${ERROR}Do not run as root!"
    exit 1
fi

#--- whiptail check ---#

if ! command -v whiptail &> /dev/null; then
    echo -e "${INFO}Installing whiptail..."
    nix-shell -p newt --run "$(realpath "$0")"
    exit $?
fi

#--- Confirm ---#

#--- Detect host + GPU ---#
# product_name alone is NOT enough on every box: the returned ThinkCentre
# reported 10LYS02F00 there, a bare machine-type string, so product_family is
# consulted too. The Victus reports "Victus by HP 15-fa1xxx" in product_name
# and sometimes "Victus" in product_family; either match is enough.
DMI_NAME="$(cat /sys/class/dmi/id/product_name 2>/dev/null || true)"
DMI_FAMILY="$(cat /sys/class/dmi/id/product_family 2>/dev/null || true)"

if grep -qi 't480s\|thinkpad\|20L8' <<<"$DMI_NAME"; then
    HOST="t480s"
    GPU="intel"
elif grep -qi 'victus' <<<"$DMI_NAME$DMI_FAMILY"; then
    HOST="victus"
    GPU="nvidia"
else
    # His call, 2026-10-16: "if thinkcenter or thinkpad else grandpa". With the
    # ThinkCentre gone (2026-10-22) this fallback is the only other box in the
    # house, so if the DMI is neither the ThinkPad nor the Victus it IS grandpa.
    HOST="grandpa"
    # No GPU. The box is headless and its GeForce GT 210 has no supported
    # driver left in nixpkgs (340.x is gone), so the card is blacklisted
    # rather than driven. Reported for confirmation only.
    GPU="none"
fi

SUMMARY="\
Username:   $CURRENT_USERNAME
Host:       ${HOST:-unknown}
GPU:        ${GPU:-unknown}
DMI seen:   name='${DMI_NAME:-}' family='${DMI_FAMILY:-}'"

if ! (whiptail --yesno "$SUMMARY\n\nProceed with installation?" 12 40 --title "NixOS Installer"); then
    exit 0
fi

#--- Set username ---#

echo -e "${INFO}Setting username to ${GREEN}$CURRENT_USERNAME${RESET}"
# variables.nix is the single source of truth; no repo-wide sed needed.
sed -i -e "s/username = \"[^\"]*\"/username = \"$CURRENT_USERNAME\"/" "hosts/${HOST}/variables.nix"

# GPU is fixed, not templated: hardware.graphics in hosts/t480s/default.nix only
# ever adds Intel media/compute packages, and there is no `gpu` key in
# variables.nix. Detection is reported for confirmation only.

#--- Prepare environment ---#

echo -e "${INFO}Preparing environment"
mkdir -p ~/Music ~/Documents ~/Pictures/wallpapers/others
ln -sf "$PWD/assets/wallpapers/wallpaper.png" ~/Pictures/wallpapers/wallpaper 2> /dev/null || true

#--- sops age key ---#
# Every host declares the fleet Telegram secrets (modules/core/monitoring.nix),
# so the first switch decrypts them. Without the private key, activation fails
# part-way through a fresh install, which is the worst possible moment to find
# out. Look for the key beside the installer or in $HOME and install it; if it
# is nowhere, stop before building a system that cannot activate.
if [ ! -f /var/lib/sops-nix/key.txt ]; then
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

#--- Hardware config ---#

if [ ! -f /etc/nixos/hardware-configuration.nix ]; then
    echo -e "${ERROR}/etc/nixos/hardware-configuration.nix not found! Aborting."
    exit 1
fi
cp /etc/nixos/hardware-configuration.nix "hosts/${HOST}/hardware-configuration.nix"

#--- Build ---#

echo -e "${INFO}Starting system build..."
sudo nixos-rebuild switch --flake ."#${HOST}"

echo -e "${OK}Done! Reboot to apply."
