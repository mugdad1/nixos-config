# nixos-config

**Not for public use.** This is my personal NixOS configuration.

Forked from [Frost-Phoenix/nixos-config](https://github.com/Frost-Phoenix/nixos-config).

## Structure

```
nixos-config/
├── flake.nix                 # Main flake
├── lib/
│   ├── default.nix           # scanPaths helper
│   └── gruvbox.nix           # Color palette
├── hosts/
│   └── t480s/
│       ├── default.nix       # Host config
│       ├── hardware.nix      # Hardware config
│       └── variables.nix     # Centralized variables
├── modules/
│   ├── core/                 # System-level
│   │   ├── boot.nix          # Bootloader
│   │   ├── hardware.nix      # Graphics, firmware
│   │   ├── network.nix       # Network, DNS, firewall
│   │   ├── security.nix      # Sudo, polkit, apparmor
│   │   ├── system.nix        # Nix settings, sysctl
│   │   ├── packages.nix      # System packages
│   │   ├── rust.nix          # Rust toolchain
│   │   └── user.nix          # User accounts
│   ├── desktop/              # Desktop environment
│   │   ├── greetd.nix        # Login manager
│   │   ├── pipewire.nix      # Audio
│   │   ├── fonts.nix         # System fonts
│   │   ├── services.nix      # Desktop services
│   │   ├── flatpak.nix       # Flatpak
│   │   └── printing.nix      # CUPS
│   └── home/                 # Home-manager modules
│       ├── shell.nix         # Zsh + p10k + aliases
│       ├── git.nix           # Git config
│       ├── browser.nix       # Zen Browser
│       ├── terminal.nix      # Ghostty
│       ├── cli.nix           # CLI packages
│       ├── dev.nix           # Dev packages
│       ├── media.nix         # GUI apps
│       ├── theme.nix         # GTK/Qt theme
│       ├── xdg.nix           # XDG + mime types
│       ├── waybar/           # Status bar
│       ├── hyprland/         # Window manager (Lua)
│       ├── rofi/             # App launcher
│       └── swaync/           # Notification center
├── scripts/                  # Shell scripts
├── fonts/                    # Font files
└── wallpapers/               # Wallpaper files
```

## Features

- **NixOS flake-based** configuration
- **Home Manager** for user packages and dotfiles
- **Hyprland** with Lua config (0.55+)
- **Gruvbox** theme throughout
- **Security hardening** (kernel sysctl, network, apparmor)
- **Auto-import** via `scanPaths` helper

## Quick Start

```bash
# Clone and install
git clone git@github.com:mugdad1/nixos-config.git
cd nixos-config
sudo nixos-rebuild switch --flake .#t480s

# Development
nix develop
```
