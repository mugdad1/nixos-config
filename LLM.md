# FrostPhoenix NixOS Config — LLM Context

## Golden Rules

1. **ALWAYS websearch before answering** — never rely on outdated knowledge. NixOS, Hyprland, asusctl, cardwire, NH, and related tools evolve fast. Verify options, syntax, and availability before suggesting anything.
2. **When user says "improve it" or similar vague improvement request** — automatically research, plan, then ask one question at a time using the question tool (never batch). The today workflow is the model: propose one change → user approves → implement → next. Keep iterating until user says stop.
3. **Never assume — always ask first.** Don't make changes or start implementing until the user explicitly says "yes" or "do it". Discussion/research is not a green light.
4. **Ask one thing at a time** using the question tool. Never batch multiple decisions into one question.
4. **Plan first** — present a clear plan before implementing. Let the user approve before writing code.
4. **Workflow: nix flake check → nixfmt → git add . → git commit → git push** — always in that order before finishing.
5. **Prefer declarative over mutable** — NixOS's strength is reproducibility. Avoid imperative hacks.
6. **Only commit when explicitly asked** — never proactively commit.
7. **No emojis in code or responses** unless the user uses them first.
8. **Be direct and concise** — no preamble, no postamble, no unnecessary explanations.

## Project Overview

Single-host NixOS flake for an ASUS ROG G513RC laptop (AMD Ryzen + NVIDIA RTX 3050). Wayland-only, Hyprland desktop, ROG laptop with full asusd + cardwire integration.

- **User:** `mugdad`
- **Host:** `rog`
- **GPU:** `amd-nvidia-hybrid` (special arg passed from flake.nix)
- **Shell:** zsh
- **State version:** 26.05, but actually running 26.11

## Directory Structure

```
nixos-config/
├── flake.nix                    # Top-level flake, single host "rog"
├── LLM.md                       # This file
├── hosts/rog/
│   ├── default.nix              # Main host config (merged: GPU + ROG + power)
│   └── hardware-configuration.nix
├── modules/
│   ├── core/                    # NixOS-level configs (services, boot, network, etc.)
│   │   ├── default.nix          # Import hub for all core modules
│   │   ├── adguardhome.nix      # Local DNS (127.0.0.1, declarative, EDNS+ratelimit=0)
│   │   ├── bluetooth.nix
│   │   ├── bootloader.nix       # Limine bootloader + gruvbox console palette
│   │   ├── cleanup.nix
│   │   ├── flatpak.nix
│   │   ├── fonts.nix
│   │   ├── hardware.nix
│   │   ├── network.nix
│   │   ├── nh.nix
│   │   ├── nixpkgs.nix
│   │   ├── pipewire.nix
│   │   ├── program.nix
│   │   ├── security.nix
│   │   ├── services.nix         # greetd+tuigreet, zramSwap, gnome-keyring, etc.
│   │   ├── system.nix           # nix settings, timezone, locale
│   │   ├── user.nix
│   │   └── wayland.nix          # programs.hyprland, xdg-portal
│   └── home/                    # Home-manager modules (hyprland, waybar, zsh, etc.)
│       ├── default.nix           # Import hub
│       ├── hyprland/             # WM config (binds, settings, monitors, etc.)
│       ├── waybar/               # Status bar
│       ├── zsh/                  # Shell + aliases
│       ├── packages/             # CLI, GUI, dev package lists
│       └── ... (30+ files)
├── scripts/
│   └── scripts/power-profile-menu.sh  # $mod+P rofi menu for GPU+profile switching
├── pkgs/                         # Custom packages
│   ├── default.nix
│   ├── maple-mono/
│   └── pomo/
├── wallpapers/
└── docs/                         # Documentation (may be outdated)
```

## Key Architecture Decisions

### GPU Switching (ROG G513RC)
- **cardwire** — eBPF-based GPU blocker, controls NVIDIA dGPU at syscall level
- **asusd** — ASUS laptop daemon, handles platform profiles (Quiet/Balanced/Performance), keyboard LEDs, charge threshold
- **MUX switch** — hardware switch at `/sys/devices/platform/asus-nb-wmi/gpu_mux_mode` (0=dGPU, 1=Optimus, requires reboot to change)
- **NO supergfxctl** — modern asusctl (OpenGamingCollective) handles GPU via firmware attributes directly
- **NO power-profiles-daemon** — asusctl's built-in platform profiles handle CPU energy preference
- **`$mod + P`** — rofi menu (`power-profile-menu.sh`) switches GPU mode + platform profile simultaneously

### Platform Profiles (asusctl)
```
asusctl profile list        # Quiet, Balanced, Performance
asusctl profile set quiet   # → low power CPU + GPU
asusctl profile set balanced
asusctl profile set performance
asusctl profile get         # Shows active, AC, and battery profiles
```

### Display Manager
- **greetd + tuigreet** — TUI greeter with gruvbox console colors (no X11/SDDM)
- Password login, no auto-login
- Starts `start-hyprland` (proper session wrapper from `programs.hyprland`)

### AdGuard Home
- Local DNS on 127.0.0.1:53
- `mutableSettings = false` (fully declarative)
- EDNS client subnet enabled, ratelimit = 0
- 27 filter lists, 7-day logs/stats

### ZRAM Swap
- `zramSwap.enable = true` (default: 50% of RAM, zstd compression)
- `vm.swappiness = 10` (only swap under memory pressure)

## Conventions

### Nix Formatters

| Formatter | Engine | Config | Semantics | Status |
|-----------|--------|--------|-----------|--------|
| **nixfmt** (rfc-style) | Haskell | None | Correct | Official RFC standard, enforced for nixpkgs. Currently used. |
| **alejandra** | Rust | None (uncompromising) | Guaranteed identical eval hash | Fast, beautiful, actively maintained. Zero config. |
| **nixpkgs-fmt** | Rust | Limited | Rules-based | Older, effectively replaced by nixfmt. |

## Nix Style
- Formatted with `nixfmt` (run before every push)
- `options` can be at top level, but then ALL config must go under a `config` attribute (use `lib.mkMerge` + `lib.mkIf` for conditional configs)
- Single host, single flake — no multi-host complexity
- `programs.nh.enable = true` for NH integration (but aliases use `nixos-rebuild` directly)

### Shell Aliases (in `modules/home/zsh/zsh_alias.nix`)
```
rebuild  → cd ~/nixos-config && nix flake check && sudo nixos-rebuild switch --flake ~/nixos-config#rog
update   → cd ~/nixos-config && nix flake check && sudo nixos-rebuild switch --upgrade --flake ~/nixos-config#rog
nft      → nh-notify nh os test
nc       → nh-notify nh clean all --keep 5
```

## Removed / Deprecated (historical context, do NOT re-add)

- **X server** (`services.xserver`) — fully removed, Wayland-only
- **SDDM** — was auto-enabled by xserver, replaced by greetd+tuigreet
- **Plymouth** — broken boot splash, removed
- **power-profiles-daemon** — replaced by asusctl platform profiles
- **supergfxctl** — deprecated by upstream asusctl, not used
- **hibernate** — not configured, swap device doesn't exist (zram only)
- **`keep-derivations` / `keep-outputs`** — deprecated nix options, silently ignored

## Important Notes for LLMs

- Hardware is ASUS ROG G513RC — check for ROG-specific quirks (asusd, MUX, dual display)
- **Always websearch for current option names** before suggesting. NixOS moves fast and things get renamed.
- The `config` vs top-level attributes issue in NixOS modules: if you use `options`, all config must go under `config` (wrapped in `lib.mkMerge` as needed)
- The user hates verbose explanations — be direct, show code, execute when approved
- `nix flake check` catches most errors before rebuild
- `scripts/` contains custom shell scripts that are actively used — check before suggesting changes
