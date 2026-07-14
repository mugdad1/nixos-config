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

#--- Confirm ---#

SUMMARY="\
Username:   $CURRENT_USERNAME
Host:       rog"

if ! (whiptail --yesno "$SUMMARY\n\nProceed with installation?" 12 40 --title "NixOS Installer"); then
    exit 0
fi

#--- Replace username ---#

echo -e "${INFO}Setting username to ${GREEN}$CURRENT_USERNAME${RESET}"
find ./modules flake.nix configuration.nix -type f -exec sed -i -e "s/mugdad/${CURRENT_USERNAME}/g" {} +

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
cp /etc/nixos/hardware-configuration.nix hardware-configuration.nix

#--- Build ---#

echo -e "${INFO}Starting system build..."
sudo nixos-rebuild switch --flake .

echo -e "${OK}Done! Reboot to apply."
