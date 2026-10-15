# nixos-config

**Not for public use.** Personal NixOS configuration.

Forked from [Frost-Phoenix/nixos-config](https://github.com/Frost-Phoenix/nixos-config).

## Hosts

Single host: the ThinkPad T480s laptop.

The host imports `../../modules/desktop` for its Sway desktop and runs the
home-manager stack from `modules/home/`. `modules/core/user.nix` imports
`modules/home` only when `variables ? browser` (which the T480s declares).

## Structure

```
nixos-config/
├── flake.nix                 # mkHost: ./hosts/${host} + sops-nix module
├── flake.lock
├── treefmt.toml              # treefmt (alejandra/shfmt/stylua/taplo)
├── rust-toolchain.toml
├── install.sh                # Guided installer (whiptail)
├── lib/
│   └── default.nix           # scanPaths helper (RECURSIVE)
├── hosts/
│   └── t480s/
│       ├── default.nix       # Laptop host config (explicit imports)
│       ├── hardware-configuration.nix   # generated — never hand-edited
│       └── variables.nix    # username, timezone, browser/terminal/launcher
├── modules/
│   ├── core/                 # Shared system layer
│   ├── desktop/              # Desktop environment — t480s only
│   └── home/                 # Home-manager stack
│       ├── default.nix       # scanPaths + ../../scripts/default.nix
│       ├── terminal/         # CLI/config files
│       ├── apps/             # browser, git, gui, vscodium, xdg
│       └── desktop/          # theme, osd, swaylock, sway, waybar, rofi, swaync
├── scripts/                 # Shell scripts (explicitly name-wrapped to PATH)
├── secrets/                 # Encrypted sops files (committed, useless without a key)
└── assets/
    ├── fonts/
    └── wallpapers/
```

## Rebuild

```bash
sudo nixos-rebuild switch --flake .#t480s
```

## Development

```bash
nix develop          # alejandra, shfmt, stylua, taplo, statix, deadnix, shellcheck, nixd
nix fmt              # format everything (formatter = alejandra)
nix flake check      # evaluate all outputs
nix build .#nixosConfigurations.t480s.config.system.build.toplevel
```

`install.sh` is a whiptail-guided installer for a fresh machine. It detects the
T480s from DMI, rewrites `username` in `hosts/t480s/variables.nix`, copies
`/etc/nixos/hardware-configuration.nix` into the host directory, links
`assets/wallpapers/wallpaper.png` into `~/Pictures/wallpapers/`, then runs
`nixos-rebuild switch --flake .#t480s`. Regenerate
`hardware-configuration.nix` on the target box at install time and diff —
never hand-write it.

## Features

- **Single host** from one flake
- **Home Manager** for user packages and dotfiles
- **Sway** compositor (Wayland, gap-less tiling) with Waybar, Rofi, SwayNC
- **Gruvbox** theme throughout
- **Blocky** local DNS resolver on `127.0.0.1:53`
- **Security hardening** — kernel sysctl, AppArmor, coredumps disabled
- **sops-nix** secrets support

## Deliberately absent / stated on purpose

- **No swap partition** — `zramSwap` covers it for the T480s
- **No server/second host components** — this configuration is laptop-only
