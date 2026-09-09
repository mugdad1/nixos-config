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
│       ├── hardware-configuration.nix # Generated hardware config
│       └── variables.nix     # Centralized variables
├── modules/
│   ├── core/                 # System-level
│   │   ├── boot.nix          # Bootloader
│   │   ├── hardware.nix      # Graphics, firmware
│   │   ├── network.nix       # Network, DNS, firewall
│   │   ├── security.nix      # Sudo, polkit, apparmor
│   │   ├── system.nix        # Nix settings, sysctl
│   │   ├── packages.nix      # System packages + Android SDK
│   │   ├── rust.nix          # Rust toolchain
│   │   ├── user.nix          # Home-manager + user accounts
│   │   ├── blocky.nix        # Encrypted local DNS resolver
│   │   ├── tailscale.nix     # Tailnet + MagicDNS
│   │   ├── snapper.nix       # Btrfs snapshots
│   │   └── nh.nix            # nix helper + GC
│   ├── desktop/              # Desktop environment
│   │   ├── wayland.nix       # greetd / wayland login
│   │   ├── pipewire.nix      # Audio
│   │   ├── fonts.nix         # System fonts
│   │   ├── services.nix      # Desktop services
│   │   ├── flatpak.nix       # Flatpak
│   └── home/                 # Home-manager modules
│       ├── shell.nix         # Zsh + p10k + aliases
│       ├── git.nix           # Git config
│       ├── browser.nix       # Zen Browser
│       ├── terminal.nix      # Ghostty (via ghostty/)
│       ├── cli.nix           # CLI packages
│       ├── dev.nix           # Dev packages
│       ├── media.nix         # GUI apps
│       ├── theme.nix         # GTK/Qt theme
│       ├── xdg.nix           # XDG + mime types
│       ├── osd.nix           # On-screen display / degradation
│       ├── vscodium.nix      # VSCodium editor
│       ├── lazyvim.nix       # Neovim + LazyVim
│       ├── waybar/           # Status bar
│       ├── hyprland/         # Window manager (Lua)
│       ├── rofi/             # App launcher
│       ├── swaync/           # Notification center
│       ├── fastfetch/        # Shell fetch
│       └── ghostty/          # Terminal emulator
├── scripts/                  # Shell scripts (auto-wrapped on PATH)
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
