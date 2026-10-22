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
# consulted too. The Victus reports "Victus by HP 15-fa1xxx" (sometimes just
# "HP Victus"), so "hp" counts as a hit as well.
#
# Override anything: HOST=grandpa ./install.sh — the DMI cannot identify a
# custom desktop and must not be trusted for a reinstall.
DMI_NAME="$(cat /sys/class/dmi/id/product_name 2>/dev/null || true)"
DMI_FAMILY="$(cat /sys/class/dmi/id/product_family 2>/dev/null || true)"

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
elif grep -qi 't480s\|thinkpad\|20L8' <<<"$DMI_NAME"; then
    HOST="t480s"
    GPU="intel"
elif grep -qi 'victus\|hp' <<<"$DMI_NAME$DMI_FAMILY"; then
    HOST="victus"
    GPU="nvidia"
else
    # His call, 2026-10-22: the fleet is grandpa + victus and grandpa is already
    # installed, so a machine the DMI cannot name is the one being installed
    # now — the Victus. Deliberately NOT grandpa: a miss here used to hand the
    # laptop the headless server's config. Reinstalling the server or the old
    # laptop takes the HOST= override above.
    HOST="victus"
    GPU="nvidia"
    echo -e "${INFO}DMI named no known host; defaulting to ${GREEN}victus${RESET} (force with HOST=<host> ./install.sh)"
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

# GPU is fixed per host, not templated: the Intel media/compute packages and
# the NVIDIA stack are declared in the host's default.nix, and there is no `gpu`
# key in variables.nix. Detection above is only used to fill this summary.

#--- Prepare environment ---#

echo -e "${INFO}Preparing environment"
mkdir -p ~/Music ~/Documents ~/Pictures/wallpapers/others
ln -sf "$PWD/assets/wallpapers/wallpaper.png" ~/Pictures/wallpapers/wallpaper 2> /dev/null || true

#--- sops age key ---#
# Hosts that declare the fleet Telegram secrets (modules/core/monitoring.nix)
# decrypt them on the first switch. Without the private key, activation fails
# part-way through a fresh install, which is the worst possible moment to find
# out. Look for the key beside the installer or in $HOME and install it; if it
# is nowhere, stop before building a system that cannot activate.
#
# victus is exempt: monitoring.nix gates the secrets off there on purpose, so it
# has nothing to decrypt and must not be blocked by a missing key.
if [ "$HOST" = "victus" ]; then
    echo -e "${INFO}${GREEN}victus${RESET} declares no sops secrets; no age key needed."
elif [ ! -f /var/lib/sops-nix/key.txt ]; then
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
