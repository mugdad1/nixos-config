# FrostPhoenix NixOS Config — LLM Context

## Golden Rules

1. **ALWAYS websearch before answering** — never rely on outdated knowledge. Verify options, syntax, and availability before suggesting anything.
2. **When user says "improve it" or similar vague improvement request** — automatically research, plan, then ask one question at a time. Propose one change → user approves → implement → next.
3. **Never assume — always ask first.** Don't make changes until the user explicitly says "yes" or "do it".
4. **Ask one thing at a time.** Never batch multiple decisions into one question.
5. **Plan first** — present a clear plan before implementing.
6. **Workflow: nix flake check → alejandra → git add . → git commit → git push** — always in that order before finishing.
7. **Prefer declarative over mutable** — NixOS's strength is reproducibility.
8. **Only commit when explicitly asked** — never proactively commit.
9. **No emojis in code or responses** unless the user uses them first.
10. **Be direct and concise** — no preamble, no postamble, no unnecessary explanations.

## Audit Workflow

When auditing modules, follow this exact format for each finding:

### Per-Finding Format
```
### Finding: [short title]
**File:** `path/to/file.nix:line_number`
**Code:**
\`\`\`nix
// exact code snippet
\`\`\`
**Sources:**
- [Source Name](URL) — date — what it says
- [Source Name](URL) — date — what it says

**Proposed Change:**
\`\`\`nix
// new code
\`\`\`

| Pro | Con |
|-----|-----|
| ... | ... |

**Verdict:** approve/reject with reasoning
```

### Rules
- **Websearch every finding** — never assume. Multiple sources, exact URLs, dates.
- **Ask 1 by 1** — present one finding, user approves/rejects, then next.
- **Not just deprecations** — look for improvements, redundancies, dead code, missing best practices.
- **Verify before suggesting** — check NixOS manual, nixpkgs commits, upstream changelogs.
- **Check actual usage** — is the feature/service/package actually used? Dead config = remove it.

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
│   └── maple-mono/
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

### Nix Style
- Formatted with `alejandra` (run before every push)
- `options` can be at top level, but then ALL config must go under a `config` attribute (use `lib.mkMerge` + `lib.mkIf` for conditional configs)
- Single host, single flake — no multi-host complexity
- `programs.nh.enable = true` for NH integration (but aliases use `nixos-rebuild` directly)

### Shell Aliases (in `modules/home/zsh/zsh_alias.nix`)
```
rebuild  → nix flake check && sudo nixos-rebuild switch --flake ~/nixos-config#rog
update   → nix flake update && nix flake check && sudo nixos-rebuild switch --flake ~/nixos-config#rog
nft      → nh-notify nh os test
nc       → nh-notify nh clean all --keep 5
ns       → nom-shell --run zsh
cdnix    → cd ~/nixos-config && codium ~/nixos-config
```

## Removed / Deprecated (historical context, do NOT re-add)

- **X server** (`services.xserver`) — fully removed, Wayland-only
- **SDDM** — was auto-enabled by xserver, replaced by greetd+tuigreet
- **Plymouth** — broken boot splash, removed
- **power-profiles-daemon** — replaced by asusctl platform profiles
- **supergfxctl** — deprecated by upstream asusctl, not used
- **hibernate** — not configured, swap device doesn't exist (zram only)
- **`keep-derivations` / `keep-outputs`** — deprecated nix options, silently ignored
- **`"splash"` kernel param** — removed from bootloader.nix
- **`hardware.alsa.enablePersistence`** — removed from pipewire.nix
- **`services.gnome.tinysparql`** — removed, nothing uses it on Hyprland
- **`openFirewall`** in AdGuard Home — removed, no web server
- **Ports 80, 443** — removed from network.nix firewall (no web server)
- **`services.sudo.enable`** and **`wheelNeedsPassword`** — removed from security.nix (both default to `true`)
- **`pinentryFlavor`** — dead comment removed from program.nix (renamed to `pinentryPackage`)
- **`nix-ld.libraries = []`** — removed empty list from program.nix
- **`fonts.fontconfig.enable = true`** — removed from fonts.nix (defaults to `true`)
- **`# twemoji-color-font`** — dead comment removed from fonts.nix
- **`packages = []`** — removed empty list from flatpak.nix
- **`user_rules = []`** — removed default noise from adguardhome.nix
- **AdGuard Home default filtering noise** — removed `parental_enabled`, `safe_search`, `safebrowsing_enabled`
- **pomo** — TUI pomodoro timer, removed (`pkgs/pomo` + `modules/home/pomo`)

## Important Notes for LLMs

- Hardware is ASUS ROG G513RC — check for ROG-specific quirks (asusd, MUX, dual display)
- **Always websearch for current option names** before suggesting. NixOS moves fast and things get renamed.
- The `config` vs top-level attributes issue in NixOS modules: if you use `options`, all config must go under `config` (wrapped in `lib.mkMerge` as needed)
- The user hates verbose explanations — be direct, show code, execute when approved
- `nix flake check` catches most errors before rebuild
- `scripts/` contains custom shell scripts that are actively used — check before suggesting changes
