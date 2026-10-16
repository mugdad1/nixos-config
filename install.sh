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
# product_name alone is NOT enough on the ThinkCentre: it reports 10LYS02F00
# there — a bare machine-type string with no product name in it — so the old
# three-way match below could never fire and install.sh aborted with
# "Could not detect host!". product_family carries the real name
# ("ThinkCentre M900x"); fall back to the 10LY machine type if family is blank.
DMI_NAME="$(cat /sys/class/dmi/id/product_name 2>/dev/null || true)"
DMI_FAMILY="$(cat /sys/class/dmi/id/product_family 2>/dev/null || true)"

if grep -qi 't480s\|thinkpad\|20L8' <<<"$DMI_NAME"; then
    HOST="t480s"
    GPU="intel"
elif grep -qi 'thinkcentre' <<<"$DMI_FAMILY" || grep -qi '^10LY' <<<"$DMI_NAME"; then
    HOST="thinkcentre"
    GPU="intel"
else
    # grandpa — his answer to "how will u know him?": the board is the AMI one
    # ("the mb is megatrends"), so bios_vendor is the tell. Checked LAST, so a
    # Megatrends BIOS on a Lenovo box still lands on thinkcentre above. If even
    # this misses (unknown board), do NOT abort like the old code did — ask.
    DMI_BIOS="$(cat /sys/class/dmi/id/bios_vendor 2>/dev/null || true)"
    if grep -qi 'megatrends' <<<"$DMI_BIOS"; then
        HOST="grandpa"
        GPU="intel"
    fi
fi

if [[ -z ${HOST:-} ]]; then
    # Auto-detection failed: ask instead of dying ("Could not detect host!" is
    # how the installer once quit mid-install-day). tags match flake outputs.
    HOST=$(whiptail --title "Host not auto-detected" \
        --menu "Which box is this? (DMI: ${DMI_NAME:-?} / family: ${DMI_FAMILY:-?})" \
        14 64 3 \
        "grandpa"      "custom desktop — i3 2nd gen, AMI Megatrends board, GT 210" \
        "thinkcentre"  "Lenovo ThinkCentre — the 512GB server" \
        "t480s"        "ThinkPad T480s" \
        3>&1 1>&2 2>&3) || exit 1
    GPU="intel"
fi

SUMMARY="\
Username:   $CURRENT_USERNAME
Host:       ${HOST:-unknown}
GPU:        ${GPU:-unknown}"

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
