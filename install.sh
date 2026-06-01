#!/usr/bin/env bash

#--------------------#
#   Initialisation   #
#--------------------#

CURRENT_USERNAME='frostphoenix'

RESET=$(tput sgr0)
WHITE=$(tput setaf 7)
BLACK=$(tput setaf 0)
RED=$(tput setaf 1)
GREEN=$(tput setaf 2)
YELLOW=$(tput setaf 3)
BLUE=$(tput setaf 4)
MAGENTA=$(tput setaf 5)
CYAN=$(tput setaf 6)
BRIGHT=$(tput bold)
UNDERLINE=$(tput smul)

OK="[${GREEN}OK${RESET}]\t"
INFO="[${BLUE}INFO${RESET}]\t"
WARN="[${MAGENTA}WARN${RESET}]\t"
ERROR="[${RED}ERROR${RESET}]\t"

set -e

#------------------------------#
#   Check if running as root   #
#------------------------------#

if [[ $EUID -eq 0 ]]; then
    echo -e "${ERROR}This script should ${RED}NOT${RESET} be executed as root!"
    echo -e "${INFO}Exiting..."
    exit 1
fi

#------------------------------------#
#   Check if whiptail is installed   #
#------------------------------------#

if ! command -v whiptail &> /dev/null; then
    echo -e "${INFO}whiptail not found, downloading required packages"
    nix-shell -p newt --run "$(realpath "$0")"
    exit $?
fi

#---------------------------------------#
#   Check if lspci (pciutils) exists    #
#---------------------------------------#

if ! command -v lspci &> /dev/null; then
    echo -e "${INFO}pciutils not found, downloading required packages"
    nix-shell -p pciutils --run "$(realpath "$0")"
    exit $?
fi

#---------------------#
#   Greating banner   #
#---------------------#

clear

echo -E "$CYAN
      _____              _   ____  _                      _        
     |  ___| __ ___  ___| |_|  _ \| |__   ___   ___ _ __ (_)_  __  
     | |_ | '__/ _ \/ __| __| |_) | '_ \ / _ \ / _ \ '_ \| \ \/ /  
     |  _|| | | (_) \__ \ |_|  __/| | | | (_) |  __/ | | | |>  <   
     |_|  |_|  \___/|___/\__|_|   |_| |_|\___/ \___|_| |_|_/_/\_\  
     _   _ _       ___        ___           _        _ _           
    | \ | (_)_  __/ _ \ ___  |_ _|_ __  ___| |_ __ _| | | ___ _ __ 
    |  \| | \ \/ / | | / __|  | || '_ \/ __| __/ _' | | |/ _ \ '__|
    | |\  | |>  <| |_| \__ \  | || | | \__ \ || (_| | | |  __/ |   
    |_| \_|_/_/\_\\\\___/|___/ |___|_| |_|___/\__\__,_|_|_|\___|_| 


       ${BLUE} ─── https://github.com/Frost-Phoenix/nixos-config ─── ${RESET}
"

#------------------#
#   Get username   #
#------------------#

while true; do
    username=$(whiptail --inputbox "Enter your username:" 9 40 --title "Username" 3>&1 1>&2 2>&3)

    if [ $? != 0 ]; then
        exit 1
    fi

    if ! [[ $username =~ ^[a-z][a-z0-9_-]{0,31}$ ]]; then
        whiptail --msgbox "Invalid username: '$username'" 8 40 --title Error 3>&1 1>&2 2>&3
        continue
    fi

    if (whiptail --yesno "Use '$username' as username?" 8 40 --title "Confirm Username"); then
        break
    fi
done

#-----------------#
#   Choose host   #
#-----------------#

while true; do
    HOST=$(whiptail --radiolist "Choose a host:" 14 56 4 \
        "desktop" "Desktop configuration" ON \
        "laptop" "Laptop configuration" OFF \
        "rog" "ASUS ROG laptop configuration" OFF \
        "vm" "Virtual machine configuration" OFF \
        --title "Host" 3>&1 1>&2 2>&3)

    if [ $? != 0 ]; then
        exit 1
    fi

    if (whiptail --yesno "Use the '$HOST' host?" 8 40 --title "Confirm Host"); then
        break
    fi
done

#------------------------------#
#   GPU profile detection      #
#------------------------------#

detect_vm() {
    if command -v systemd-detect-virt &>/dev/null && systemd-detect-virt --quiet &>/dev/null; then
        return 0
    fi
    for f in /sys/class/dmi/id/product_name /sys/class/dmi/id/sys_vendor; do
        if [ -r "$f" ] && grep -Eqi 'qemu|kvm|vmware|virtualbox|hyper-v' "$f" 2>/dev/null; then
            return 0
        fi
    done
    return 1
}

GPU_DETECTED=""

has_nvidia=false
has_intel=false
has_amd=false
has_vm=false

if detect_vm; then
    has_vm=true
fi

if lspci -nn | grep -qi 'vga\|3d\|display'; then
    while IFS= read -r line; do
        if echo "$line" | grep -Eqi 'nvidia'; then
            has_nvidia=true
        fi
        if echo "$line" | grep -Eqi 'amd|ati|advanced micro devices'; then
            has_amd=true
        fi
        if echo "$line" | grep -Eqi 'intel'; then
            has_intel=true
        fi
        if echo "$line" | grep -Eqi 'virtio|vmware|virtualbox|qxl|qemu|bochs|cirrus'; then
            has_vm=true
        fi
    done < <(lspci -nn | grep -i 'vga\|3d\|display')
fi

if $has_vm; then
    GPU_DETECTED="vm"
elif $has_nvidia && $has_amd; then
    GPU_DETECTED="amd-nvidia-hybrid"
elif $has_nvidia && $has_intel; then
    GPU_DETECTED="nvidia-prime"
elif $has_nvidia; then
    GPU_DETECTED="nvidia"
elif $has_amd; then
    GPU_DETECTED="amd"
elif $has_intel; then
    GPU_DETECTED="intel"
fi

#------------------------------#
#   GPU profile selection      #
#------------------------------#

if [ -n "$GPU_DETECTED" ]; then
    if (whiptail --yesno "Detected GPU profile: ${GPU_DETECTED}\n\nIs this correct?" 10 40 --title "GPU Detection"); then
        GPU="$GPU_DETECTED"
    else
        GPU=""
    fi
fi

if [ -z "$GPU" ]; then
    GPU=$(whiptail --radiolist "Select GPU profile:" 17 56 7 \
        "amd" "AMD GPU" ON \
        "amd-nvidia-hybrid" "AMD iGPU + NVIDIA dGPU (Prime offload)" OFF \
        "intel" "Intel GPU" OFF \
        "nvidia" "NVIDIA GPU" OFF \
        "nvidia-prime" "NVIDIA Optimus (Intel+NVIDIA)" OFF \
        "vm" "VM guest services" OFF \
        --title "GPU Profile" 3>&1 1>&2 2>&3)
    if [ $? != 0 ]; then
        exit 1
    fi
fi

#------------------------#
#   pkgs configuration   #
#------------------------#

whiptail --msgbox "This config includes Aseprite, a pixel art editing software. It requires being built from source, which can take a very long time depending on your hardware. You will have the option to disable it, with the intent of speeding up the installation." 12 60 --title "Aseprite Information"
if (whiptail --yesno "Disable Aseprite (faster install)?" --defaultno 8 40 --title "Aseprite"); then
    DISABLE_ASEPRITE="Yes"
else
    DISABLE_ASEPRITE="No"
fi

#---------------------------#
#   Recap of user choices   #
#---------------------------#

SUMMARY="\
Username:   $username
Host:       $HOST
GPU:        $GPU

Disable Aseprite:   $DISABLE_ASEPRITE
"

whiptail --msgbox "$SUMMARY" 11 40 --title "Installation Summary"

#-----------------------#
#   Last Confirmation   #
#-----------------------#

if ! (whiptail --yesno "You are about to build the system for host '$HOST'. Proceed?" 9 40 --title "Final Confirmation"); then
    exit 0
fi

#---------------------#
#   Change username   #
#---------------------#

echo -e "${INFO}Changing username to ${GREEN}$username${RESET}"
find ./hosts ./modules flake.nix -type f -exec sed -i -e "s/${CURRENT_USERNAME}/${username}/g" {} +

echo -e "${INFO}Setting GPU profile to ${GREEN}$GPU${RESET}"
sed -i "s/gpu = \"[a-z-]*\"/gpu = \"$GPU\"/" flake.nix

if [[ $ROG_ENABLED = "Yes" ]]; then
    echo -e "${INFO}Enabling ASUS ROG tools for host ${GREEN}$HOST${RESET}"
    HOST_FILE="hosts/${HOST}/default.nix"
    if ! grep -q "modules/rog" "$HOST_FILE" 2>/dev/null; then
        sed -i "/\.\/hardware-configuration\.nix/a\    ./../../modules/rog" "$HOST_FILE"
    fi
fi

#------------------------------#
#   Apply pkgs configuration   #
#------------------------------#

if [[ $DISABLE_ASEPRITE = "Yes" ]]; then
    echo -e "${INFO}Disabling Aseprite"
    sed -i '3s/  /  # /' modules/home/aseprite/aseprite.nix
fi

#----------------------#
#   Clear git config   #
#----------------------#

echo -e "${INFO}Clearing git config"
sed -i 's/"Frost-Phoenix"/""/g' modules/home/git.nix
sed -i 's/"67cyril6767@gmail.com"/""/g' modules/home/git.nix

#------------------------------#
#   Prepare the environement   #
#------------------------------#

## Create common dirrectories
echo -e "${INFO}Preparing the environment"
for dir in ~/Music ~/Documents ~/Pictures/wallpapers/others; do
    echo -e "${INFO}Creating folder: ${MAGENTA}${dir}${RESET}"
    mkdir -p "$dir"
done

## Copy wallpapers
echo -e "${INFO}Copying wallpapers..."
if cp -r wallpapers/otherWallpaper/gruvbox/* ~/Pictures/wallpapers/others/ &&
    cp -r wallpapers/otherWallpaper/nixos/* ~/Pictures/wallpapers/others/ &&
    ln -sf $PWD/wallpapers/wallpaper.png ~/Pictures/wallpapers/wallpaper; then
    echo -e "${OK}Wallpapers copied successfully."
else
    echo -e "${WARN}Some wallpapers could not be copied!"
    whiptail --msgbox "Some wallpapers failed to copy." 8 40 --title "Warning"
fi

## Get the hardware configuration
if [ ! -f /etc/nixos/hardware-configuration.nix ]; then
    echo -e "${ERROR} ${MAGENTA}/etc/nixos/hardware-configuration.nix${RESET} not found! Aborting."
    whiptail --msgbox "/etc/nixos/hardware-configuration.nix not found! Aborting." 9 40 --title "Error"
    exit 1
fi
echo -e "${INFO}Copying ${MAGENTA}/etc/nixos/hardware-configuration.nix${RESET} to ${MAGENTA}./hosts/${HOST}/${RESET}"
cp /etc/nixos/hardware-configuration.nix hosts/${HOST}/hardware-configuration.nix

#------------------#
#   Installation   #
#------------------#

echo -e "${INFO}Starting system build... this may take a while."
sudo nixos-rebuild switch --flake .#${HOST}

echo -e "${INFO}System build finished successfully"
echo -e "${INFO}You can now reboot to apply the config"
