# nixos-config

Personal NixOS flake for three machines. **Not for public use.** Originally
forked from [Frost-Phoenix/nixos-config](https://github.com/Frost-Phoenix/nixos-config).

Long-form documentation lives in the wiki: `~/projects/wiki/projects/nixos-config.md`
(history and decisions: `~/projects/wiki/decisions.md`).

## Hosts

All three deploy from `main`.

| Host | Role | Platform |
| --- | --- | --- |
| `victus` | Daily laptop — Sway + Hyprland, home-manager, Intel iGPU + RTX 3050 | HP Victus 15, i5-12500H |
| `t480s` | Second laptop — Sway + Hyprland, home-manager, Intel iGPU only | ThinkPad T480s |
| `grandpa` | Headless server — Forgejo, gitea-mirror, nginx, HA, SearXNG, study, blocky, Docker engine, backups | Custom i3-2120 |

`grandpa` imports `modules/core` only: no desktop, no home-manager. Its
`variables.nix` declares no `browser`/`terminal`/`launcher`, and
`modules/core/user.nix` imports `modules/home` only when `variables ? browser`.

## Layout

```
flake.nix                 # mkHost: hosts/<host> + sops-nix; specialArgs host/inputs/variables
lib/default.nix           # scanPaths — recursive module auto-import
lib/gruvbox.nix           # palette
lib/server-index.nix      # grandpa's index page
hosts/
  victus/                 # default.nix, battery-charge-limit.nix, hardware-configuration.nix, variables.nix
  t480s/                  # default.nix, hardware-configuration.nix, variables.nix
  grandpa/                # default.nix, packages.nix, overrides.nix, backup.nix, router-reboot.nix,
                          #   home-assistant.nix, services.nix, secrets.nix, searxng.nix, gitea-mirror.nix,
                          #   hardware-configuration.nix, variables.nix
modules/
  core/                   # shared system layer — every host (17 files)
  desktop/                # desktop environment — laptops only (9 files)
  home/                   # home-manager stack — only where variables declare a desktop
    terminal/             # cli, dev, fish, foot, glow, lazyvim, shell
    apps/                 # browser, git, gui, homepage, vscodium, xdg
    desktop/              # theme, osd, swaylock + sway/, hyprland/, waybar/, rofi/, swaync/
pkgs/                     # callPackage files: filen-cli.nix, filen-desktop.nix, gitea-mirror.nix
scripts/                  # wrapped shell scripts (scripts/default.nix)
  grandpa/ac.sh           # read directly by hosts/grandpa/packages.nix
secrets/fleet.sops.yaml   # encrypted sops file (committed; useless without the age key)
assets/fonts/ assets/wallpapers/
```

## Import rules

These are opposite on purpose. Getting either wrong fails silently — a green
build says nothing about a file that was never imported.

1. **`hosts/<name>/` — explicit imports only.** A directory module resolves to
   its `default.nix` only; it does not sweep up siblings. Every file under
   `hosts/<name>/` must be named in that host's `imports` list.
2. **`modules/{core,desktop,home}/` — recursive `scanPaths`.** Any `.nix` file
   dropped in these trees is imported; a subdirectory with its own
   `default.nix` owns its children. `modules/home/default.nix` additionally
   imports `scripts/default.nix`, which is outside the tree.
3. **`scripts/` — explicit.** Each script is wrapped by name in
   `scripts/default.nix`. `scripts/grandpa/ac.sh` is read directly by the
   grandpa package list, which has no home-manager.

Verify a new unit with `nix eval` on `config.systemd.services.<name>` rather
than trusting the build result.

## Rebuild

```bash
mcli rebuild                 # nh os switch ~/nixos-config; host from hostname
mcli update                  # flake update + rebuild

sudo nixos-rebuild switch --flake ~/nixos-config#victus
sudo nixos-rebuild switch --flake ~/nixos-config#t480s
sudo nixos-rebuild switch --flake ~/nixos-config#grandpa
```

## Secrets

The repo is public, so no credential is written in Nix. Encrypted
`secrets/fleet.sops.yaml` is committed; the private age key never is.

`grandpa` is the only host that declares sops secrets (`filen/*`, `searx/secret_key`).
Its key lives at `/var/lib/sops-nix/key.txt` (mode 600, root:root) and must be
restored before the first switch on a fresh install, or activation fails while
decrypting. The laptops hold no age key.

Edit with `sops secrets/fleet.sops.yaml`; declare a secret in `sops.secrets` and
read it via `config.sops.placeholder."<name>"`.

## Development

```bash
nix develop                  # alejandra, shfmt, stylua, taplo, statix, deadnix, shellcheck, nixd
nix fmt                      # treefmt (alejandra/shfmt/stylua/taplo)
alejandra --check $(git ls-files '*.nix')
statix check
deadnix --fail
nix flake check
```

`nix fmt` currently fails when `stylua` is not on `PATH`; run `alejandra`
directly in that case.

`install.sh` is a whiptail installer for a fresh machine. It detects the host
from DMI, rewrites `username`, copies `/etc/nixos/hardware-configuration.nix`
into the host directory, and runs the first switch. Regenerate
`hardware-configuration.nix` on the target and diff — never hand-write it.
