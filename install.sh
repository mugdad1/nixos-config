#!/usr/bin/env bash

set -euo pipefail

CURRENT_USERNAME=$(whoami)

RESET=$(tput sgr0)
RED=$(tput setaf 1)
GREEN=$(tput setaf 2)
BLUE=$(tput setaf 4)

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
fi

if [[ -z ${HOST:-} ]]; then
    echo -e "${ERROR}Could not detect host! Aborting."
    exit 1
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
ln -sf "$PWD/wallpapers/wallpaper.png" ~/Pictures/wallpapers/wallpaper 2> /dev/null || true

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
