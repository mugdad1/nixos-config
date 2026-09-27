# nixos-config

**Not for public use.** This is my personal NixOS configuration.

Forked from [Frost-Phoenix/nixos-config](https://github.com/Frost-Phoenix/nixos-config).

## Hosts

Single host. The `asus` home server was removed in September 2026 — see
[History](#history).

| Host  | Role                                  | Platform        |
| ----- | ------------------------------------- | --------------- |
| t480s | Laptop — Sway desktop, home-manager   | ThinkPad T480s  |

## Structure

```
nixos-config/
├── flake.nix                 # Main flake
├── flake.lock
├── treefmt.toml              # treefmt (alejandra/shfmt/stylua/taplo)
├── rust-toolchain.toml
├── install.sh                # Guided installer (whiptail)
├── lib/
│   ├── default.nix           # scanPaths helper
│   └── gruvbox.nix           # Color palette
├── hosts/
│   └── t480s/                # The only host
│       ├── default.nix       # Host config
│       ├── hardware-configuration.nix
│       └── variables.nix     # Per-host variables (username, browser, …)
├── modules/
│   ├── core/                 # Shared system-level
│   │   ├── default.nix       # scanPaths import
│   │   ├── blocky.nix        # Encrypted local DNS resolver (DoQ + DoT)
│   │   ├── boot.nix, system.nix, security.nix, network.nix
│   │   ├── hardware.nix, packages.nix, rust.nix, user.nix
│   │   └── nh.nix            # nix helper + GC
│   ├── desktop/              # Desktop environment
│   │   ├── default.nix       # scanPaths import
│   │   ├── wayland.nix       # XDG portal config
│   │   ├── pipewire.nix, fonts.nix, services.nix, flatpak.nix
│   │   └── printing.nix
│   └── home/                 # Home-manager modules
│       ├── default.nix       # scanPaths import
│       ├── browser.nix (Zen), shell.nix, fish.nix, git.nix, glow.nix
│       ├── cli.nix, dev.nix, gui.nix, theme.nix, xdg.nix, osd.nix
│       ├── vscodium.nix, lazyvim.nix, swaylock.nix
│       ├── sway/, waybar/, rofi/, swaync/, fastfetch/, ghostty/
│       └── lazyvim-config/
├── scripts/                  # Shell scripts (auto-wrapped on PATH)
├── fonts/                    # Font files
└── wallpapers/               # Wallpaper files
```

Every `modules/*/` directory uses the `scanPaths` helper in `lib/default.nix`,
so a new `.nix` file is picked up automatically — no import list to maintain.

## Features

- **Single-host** NixOS flake configuration
- **Home Manager** for user packages and dotfiles
- **Sway** compositor (Wayland, gap-less tiling) with Waybar, Rofi, SwayNC
- **Gruvbox** theme throughout
- **Blocky** as the local encrypted DNS resolver, raced DoQ/DoT upstreams
- **Security hardening** — kernel sysctl, AppArmor, coredumps disabled
- **Auto-import** via the `scanPaths` helper

### Deliberately absent

Worth knowing so they are not mistaken for oversights:

- **No inbound firewall ports.** Nothing is listening on the LAN, and there is no
  `openssh` server — only the gnupg/ssh *agent* client. If a service ever needs a
  port, it should open it in the module that configures that service.
- **No swap partition.** `zramSwap` in `modules/desktop/services.nix` handles
  swap in RAM.
- **No CSS/JS tooling in the config** — none needed.

## Quick Start

```bash
git clone git@github.com:mugdad1/nixos-config.git
cd nixos-config
sudo nixos-rebuild switch --flake .#t480s

# Development
nix develop          # alejandra, shfmt, stylua, taplo, nixfmt-rfc-style
nix fmt              # format everything
nix flake check      # evaluate all outputs
```

`install.sh` is a whiptail-guided installer for a fresh machine. It detects the
host from `/sys/class/dmi/id/product_name` and rewrites `username` in
`hosts/t480s/variables.nix`. It does **not** template the GPU — that is fixed to
Intel in `hosts/t480s/default.nix`.

## History

The configuration originally covered two hosts: `t480s` (laptop) and `asus` (a
headless home server on a Tailscale tailnet). The `asus` host and everything that
served it — `modules/server/`, `packages/gitea-mirror.nix`, the Gitea +
postgres + mirror stack, tailnet/MagicDNS routing, and the Blocky LAN upstreams —
were removed in September 2026. `nixos-rebuild --flake .#asus` no longer exists.

What replaced the server: nothing. It was a convenience setup, not a dependency.
Anything that had been mirrored to it now lives only on the laptop and on GitHub.
