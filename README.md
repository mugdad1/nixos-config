# nixos-config

**Not for public use.** This is my personal NixOS configuration.

Forked from [Frost-Phoenix/nixos-config](https://github.com/Frost-Phoenix/nixos-config).

## Hosts

| Host  | Role                        | Platform     |
| ----- | --------------------------- | ------------ |
| t480s | Desktop (Hyprland + GUI)    | ThinkPad T480s |
| asus  | Headless home server (tailnet-only) | ASUS i3-8th gen |

## Structure

```
nixos-config/
├── flake.nix                 # Main flake
├── flake.lock
├── treefmt.toml              # treefmt (alejandra/shfmt/stylua/taplo)
├── install.sh
├── lib/
│   ├── default.nix           # scanPaths helper
│   └── gruvbox.nix           # Color palette
├── hosts/
│   ├── t480s/                # Desktop host (Hyprland, home-manager)
│   │   ├── default.nix       # Host config
│   │   ├── hardware-configuration.nix
│   │   └── variables.nix
│   └── asus/                 # Headless server host
│       ├── default.nix
│       ├── hardware-configuration.nix
│       └── variables.nix
├── modules/
│   ├── core/                 # Shared system-level
│   │   ├── boot.nix, system.nix, security.nix, network.nix
│   │   ├── hardware.nix, packages.nix, rust.nix, user.nix
│   │   ├── blocky.nix        # Encrypted local DNS resolver
│   │   ├── tailscale.nix     # Tailnet + MagicDNS
│   │   ├── snapper.nix       # Btrfs snapshots
│   │   ├── nh.nix            # nix helper + GC
│   │   └── default.nix
│   ├── desktop/              # Desktop environment
│   │   ├── wayland.nix       # Hyprland + xdg portals
│   │   ├── pipewire.nix, fonts.nix, services.nix, flatpak.nix
│   ├── server/               # Server services (asus only)
│   │   ├── gitea.nix         # Gitea on :3000 + shared postgres
│   │   ├── gitea-mirror.nix  # GitHub→Gitea mirror on :4321
│   │   ├── network.nix, openssh.nix, packages.nix, memory.nix, user.nix
│   │   └── default.nix       # scanPaths import
│   └── home/                 # Home-manager modules (t480s)
│       ├── shell.nix, fish.nix, git.nix, browser.nix (Zen)
│       ├── cli.nix, dev.nix, gui.nix, theme.nix, xdg.nix, osd.nix
│       ├── vscodium.nix, lazyvim.nix
│       ├── waybar/, hyprland/ (with hypridle.nix), rofi/
│       ├── swaync/, fastfetch/, ghostty/, lazyvim-config/
│       └── default.nix
├── packages/
│   └── gitea-mirror.nix      # Self-built gitea-mirror app (no upstream flake)
├── scripts/                  # Shell scripts (auto-wrapped on PATH)
├── fonts/                    # Font files
└── wallpapers/               # Wallpaper files
```

## Features

- **NixOS flake-based** configuration, two hosts
- **Home Manager** for user packages and dotfiles (t480s)
- **Hyprland** with Lua config (0.55+)
- **Gruvbox** theme throughout
- **Security hardening** (kernel sysctl, network, apparmor)
- **Auto-import** via `scanPaths` helper
- **Server stack** on asus: Gitea + GitHub→Gitea mirror — tailscale-only, no open firewall

## Server services (asus)

Reachable over tailnet via MagicDNS. Firewall stays closed; tailscale routes bypass it.

| Service          | URL        | Notes                                          |
| ---------------- | ---------- | ---------------------------------------------- |
| Gitea            | `http://asus:3000` | Git host, postgres backend              |
| gitea-mirror     | `http://asus:4321` | Mirrors GitHub repos to Gitea (self-built) |

First-run setup:

- **gitea-mirror** needs `/var/lib/gitea-mirror/env` (root:600) before the first
  start, e.g. `BETTER_AUTH_URL=http://asus:4321` (see
  `modules/server/gitea-mirror.nix`). Secrets are auto-generated on first boot.

## Quick Start

```bash
git clone git@github.com:mugdad1/nixos-config.git
cd nixos-config
sudo nixos-rebuild switch --flake .#t480s   # desktop
sudo nixos-rebuild switch --flake .#asus    # server

# Development
nix develop
```