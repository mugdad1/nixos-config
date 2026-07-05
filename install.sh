#!/usr/bin/env bash

set -e

CURRENT_USERNAME=$(whoami)

RESET=$(tput sgr0)
RED=$(tput setaf 1)
GREEN=$(tput setaf 2)
YELLOW=$(tput setaf 3)
BLUE=$(tput setaf 4)
MAGENTA=$(tput setaf 5)
CYAN=$(tput setaf 6)
BRIGHT=$(tput bold)

OK="[${GREEN}OK${RESET}]\t"
INFO="[${BLUE}INFO${RESET}]\t"
WARN="[${MAGENTA}WARN${RESET}]\t"
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

#--- Detect host + GPU ---#

if grep -qi 'rog\|g513' /sys/class/dmi/id/product_name 2> /dev/null; then
    HOST="rog"
    GPU="amd-nvidia-hybrid"
elif grep -qi 't480s\|thinkpad\|20L8' /sys/class/dmi/id/product_name 2> /dev/null; then
    HOST="t480s"
    GPU="intel"
fi

SUMMARY="\
Username:   $CURRENT_USERNAME
Host:       ${HOST:-unknown}
GPU:        ${GPU:-unknown}"

if ! (whiptail --yesno "$SUMMARY\n\nProceed with installation?" 12 40 --title "NixOS Installer"); then
    exit 0
fi

#--- Replace username ---#

echo -e "${INFO}Setting username to ${GREEN}$CURRENT_USERNAME${RESET}"
find ./hosts ./modules flake.nix -type f -exec sed -i -e "s/mugdad/${CURRENT_USERNAME}/g" {} +

echo -e "${INFO}Setting GPU profile to ${GREEN}$GPU${RESET}"
sed -i "s/gpu = \"[a-z-]*\"/gpu = \"$GPU\"/" flake.nix

#--- Clear git config ---#

echo -e "${INFO}Clearing git config"
sed -i 's/"Frost-Phoenix"/""/g' modules/home/git.nix
sed -i 's/"67cyril6767@gmail.com"/""/g' modules/home/git.nix

#--- Prepare environment ---#

echo -e "${INFO}Preparing environment"
mkdir -p ~/Music ~/Documents ~/Pictures/wallpapers/others
cp -r wallpapers/otherWallpaper/gruvbox/* ~/Pictures/wallpapers/others/ 2> /dev/null || true
cp -r wallpapers/otherWallpaper/nixos/* ~/Pictures/wallpapers/others/ 2> /dev/null || true
ln -sf "$PWD/wallpapers/wallpaper.png" ~/Pictures/wallpapers/wallpaper 2> /dev/null || true

#--- Hardware config ---#

if [ ! -f /etc/nixos/hardware-configuration.nix ]; then
    echo -e "${ERROR}/etc/nixos/hardware-configuration.nix not found! Aborting."
    exit 1
fi
cp /etc/nixos/hardware-configuration.nix "hosts/${HOST}/hardware-configuration.nix"

#--- Build ---#

echo -e "${INFO}Starting system build..."
sudo nixos-rebuild switch --flake .#${HOST}

echo -e "${OK}Done! Reboot to apply."
