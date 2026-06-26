# Improvement Plan for `nixos-config`

**Generated:** 2026-06-26
**Context:** Based on codebase analysis of `/home/mugdad/nixos-config` and web research into current NixOS best practices.

---

## Priority Legend

| Icon | Meaning |
|------|---------|
| 🔴 | Bug / breakage risk |
| 🟡 | Maintenance / deprecation |
| 🔵 | Quality of life |
| 🟢 | Feature / nice-to-have |

---

## Package-Level Suggestions

### 1. 🔵 Remove Niche / Potentially Unused CLI Packages

**File:** `modules/home/packages/cli.nix`

Some packages are highly niche and possibly unused:

| Package | Note |
|---------|------|
| `cliamp` | Very niche CLI audio player. Consider `mpv` instead (also GUI). |
| `opencode` | This is the tool you're talking to me through — likely you know if you use it. |
| `gtrash` | If you use `trash-cli` or just `rm`, this might be redundant. |
| `ripdrag` | Drag-and-drop from terminal — niche, only useful with specific file managers. |
| `socat` | Powerful but niche — only needed if you do networking debugging. |

**Action:** Review and remove anything you don't actually use. Every package adds to build time and closure size.

---

### 2. 🔵 Add Useful CLI Tools (Consider These)

**File:** `modules/home/packages/cli.nix`

| Tool | Why |
|------|-----|
| `tealdeer` | Faster Rust rewrite of `tldr` (already have `tldr`) |
| `hyperfine` | Command-line benchmarking tool |
| `dust` | Alternative to `du` — more intuitive output |
| `procs` | Modern `ps` replacement with colorized output |
| `sd` | Modern `sed` replacement — much simpler syntax |
| `ouch` | Unarchive any format with one command (.zip, .tar.*, .rar, .7z) |
| `zellij` | Terminal multiplexer alternative to tmux |
| `lazygit` | TUI git client — pairs well with your fugitive/nvim setup |
| `delta` | Enhanced git diff viewer (you may already use this via git.nix) |
| `dog` / `dogdns` | Modern `dig` replacement with colorized output |

---

### 3. 🔵 GUI Apps: Additions

**File:** `modules/home/packages/gui.nix`

| Tool | Why |
|------|-----|
| `mpv` | Lighter, faster than VLC with better Wayland support. VLC can stay as secondary. |
| `obsidian` | Note-taking app if you need it |
| `font-manager` | GUI to browse/manage installed fonts |
| `imv` | Already in cli.nix but is actually a GUI image viewer — move it here |

**Note:** `imv` is currently in `cli.nix:24` but it's a GUI image viewer. Move to `gui.nix` for consistency.

---

### 4. 🔵 Nix Tools: Audit the Niche Ones

**File:** `modules/home/packages/nix.nix`

These are all developer-focused Nix inspection tools. Likely not all are needed day-to-day:

| Package | Usage |
|---------|-------|
| `nvd` | See what changed between NixOS generations — very useful |
| `nix-output-monitor` | Pretty `nix build` output — useful |
| `nix-tree` | Interactive Nix store dependency browser |
| `nix-du` | Find what's taking space in the Nix store |
| `nix-btm` | Bottom-like system monitor for Nix |
| `nix-web` | Web UI for Nix store |
| `nix-melt` | Ranger-like flake.lock viewer |
| `nixtract` | Extract derivation graph from a flake |

**Action:** If you rarely use some of these, remove them. They all share the Nix dependency so build time is minimal, but it's still clutter. `nvd` and `nix-output-monitor` are the most commonly used.

---

### 5. 🔵 Add `gh` (GitHub CLI) if Not Present

**File:** `modules/home/git.nix` or `packages/cli.nix`

`gh` is the official GitHub CLI — useful for PR management, issues, workflows. Not found in your package lists. If you manage this repo from CLI, this is essential.

---

### 6. 🔴 Fix `brightnessctl` Duplication

**Files:** `hosts/rog/default.nix:148`, `hosts/t480s/default.nix:61`

`brightnessctl` is added in both host files. It's a generic tool that works on any laptop/desktop with backlight control.

**Action:** Move to `modules/core/system.nix` or `modules/home/packages/cli.nix`:

```diff
-  # Remove from both hosts/rog/default.nix and hosts/t480s/default.nix
-  environment.systemPackages = with pkgs; [ brightnessctl ];
+  # Add once in modules/home/packages/cli.nix or modules/core/system.nix
+  home.packages = with pkgs; [ brightnessctl ... ];
```

---

## Config-Level Suggestions

### 7. 🔴 AdGuard Password Is Hardcoded Plaintext (Bcrypt, but Still)

**File:** `modules/core/adguardhome.nix:11`

```nix
password = "$2b$05$Ql8dSXIbLyBwncygqV.2JeTW6Kiop/sWmDLYaMGJXzMzbOKqyM.G.";
```

This is a bcrypt hash, not plaintext, so it's not immediately leakable. However:
- Anyone who clones your repo knows this hash and can brute-force it offline
- The hash never changes unless you manually update the config
- This is a perfect candidate for your first **agenix** secret

**Action:** Move to agenix:

```nix
# modules/core/adguardhome.nix
{ config, ... }: {
  services.adguardhome.settings.users = [{
    name = "mugdad";
    password = builtins.readFile config.age.secrets.adguard-password.path;
  }];
  age.secrets.adguard-password.file = ../secrets/adguard-password.age;
}
```

---

### 8. 🟡 `boot.kernelPackages` Override Is Redundant

**Files:** `modules/core/bootloader.nix:76`, `hosts/rog/default.nix:142`

- `bootloader.nix:76` → `boot.kernelPackages = pkgs.linuxPackages_latest;` (priority 100)
- `hosts/rog/default.nix:142` → `boot.kernelPackages = lib.mkDefault pkgs.linuxPackages_latest;` (priority 1000)

Both set the same value, but `mkDefault` has *lower* priority than the plain set. So the bootloader's value always wins and rog's `mkDefault` is a no-op. No functional issue, but misleading.

**On t480s:** No override, so it inherits `linuxPackages_latest` from bootloader — fine.

**Action:** Remove the redundant `mkDefault` from `rog/default.nix`. If rog needs a different kernel, make it explicit with the correct priority:

```diff
-  # hosts/rog/default.nix — delete this line
-  boot.kernelPackages = lib.mkDefault pkgs.linuxPackages_latest;
```

---

### 9. 🟡 `upower` Duplicated in Both Hosts

**Files:** `hosts/rog/default.nix:163-169`, `hosts/t480s/default.nix:52-58`

Both hosts have identical `upower` config:

```nix
services.upower = {
  enable = true;
  percentageLow = 20;
  percentageCritical = 5;
  percentageAction = 3;
  criticalPowerAction = "PowerOff";
};
```

**Action:** Move to `modules/core/services.nix` or create `modules/core/power.nix`.

---

### 10. 🟡 `/etc/resolv.conf` May Break Without `resolved`

**Files:** `modules/core/network.nix:9`, `modules/core/adguardhome.nix:102`

```nix
# network.nix
networking.nameservers = ["127.0.0.1"];

# adguardhome.nix
services.resolved.enable = false;
```

With `resolved` disabled, setting `nameservers` in `networking` is handled by NetworkManager's `dns=default` behavior. This works if NetworkManager writes `/etc/resolv.conf` with `127.0.0.1`. But without `resolved`, there's no local DNS stub resolver — AdGuard must be running for DNS to work.

**Verify:** Run `cat /etc/resolv.conf` on your system. If it shows `127.0.0.1` and DNS works, this is fine. If not, you may need `networking.networkmanager.dns = "none"` with a manual symlink, or keep `resolved` in `proxy` mode.

---

### 11. 🟢 Add `hypridle` for Auto-Suspend

**Currently:** You have `hyprlock` (PAM service) but no idle daemon. Your laptop won't auto-suspend on idle.

**Action:** Add to home-manager:

```nix
# modules/home/hyprland/hypridle.nix (new)
{ ... }: {
  services.hypridle = {
    enable = true;
    settings = {
      general = {
        lock_cmd = "pidof hyprlock || hyprlock";
        unlock_cmd = "pidof hyprlock && killall hyprlock || true";
        before_sleep_cmd = "loginctl lock-session";
        after_sleep_cmd = "hyprctl dispatch dpms on";
      };
      listener = [
        { timeout = 300; on-timeout = "brightnessctl -s set 10"; }
        { timeout = 600; on-timeout = "loginctl lock-session"; }
        { timeout = 900; on-timeout = "hyprctl dispatch dpms off"; }
        { timeout = 1200; on-timeout = "systemctl suspend"; }
      ];
    };
  };
}
```

---

### 12. 🟢 Add Periodic Garbage Collection

**File:** `modules/core/system.nix`

`nh` cleans during rebuild, but if you go weeks without rebuilding, the store grows unbounded.

**Add:**

```nix
nix.gc = {
  automatic = true;
  dates = "weekly";
  options = "--delete-older-than 30d";
};
```

Optionally, add low-disk-space GC triggers:

```nix
nix.settings = {
  min-free = 5 * 1024 * 1024 * 1024;  # 5 GB
  max-free = 10 * 1024 * 1024 * 1024; # 10 GB
};
```

---

### 13. 🟢 Configure ZRAM Algorithm and Size

**File:** `modules/core/services.nix:48-49`

```nix
zramSwap.enable = true;
boot.kernel.sysctl."vm.swappiness" = 10;
```

**Improve:**

```nix
zramSwap = {
  enable = true;
  memoryPercent = 50;        # Use 50% of RAM for zram (default)
  algorithm = "zstd";        # Better compression than default lzo
};
```

---

### 14. 🟢 Add `syncthing` for File Sync Between Hosts

**File:** new `modules/core/syncthing.nix`

If you want to sync files between `rog` and `t480s`:

```nix
services.syncthing = {
  enable = true;
  user = "mugdad";
  dataDir = "/home/mugdad/syncthing";
  configDir = "/home/mugdad/.config/syncthing";
  overrideDevices = true;    # managed declaratively
  overrideFolders = true;
};
```

---

### 15. 🟢 Add Printing Support

**File:** new `modules/core/printing.nix`

```nix
services.printing = {
  enable = true;
  drivers = [ pkgs.gutenprint ];
};

services.avahi = {
  enable = true;
  nssmdns = true;
  publish = {
    enable = true;
    addresses = true;
    workstation = true;
  };
};
```

---

### 16. 🔵 Add LTS Kernel Option for t480s

**File:** `hosts/t480s/default.nix`

Both hosts run `linuxPackages_latest`. The t480s (2018 Intel laptop) doesn't benefit from the latest kernel as much as rog (which needs it for NVIDIA/AMD GPU support). Running latest on both means more frequent reboots for kernel updates.

**Optional:** Pin t480s to `linuxPackages_6_12` (current LTS):

```nix
boot.kernelPackages = pkgs.linuxPackages_6_12;
```

This means fewer forced reboots on the laptop.

---

### 17. 🔵 PipeWire: Add WirePlumber Bluetooth Config

**File:** `modules/core/pipewire.nix`

If you use Bluetooth audio (headphones, speakers):

```nix
services.pipewire.wireplumber.extraConfig."10-bluez" = {
  "monitor.bluez.properties" = {
    "bluez5.enable-sbc-xq" = true;
    "bluez5.enable-msbc" = true;
    "bluez5.enable-hw-volume" = true;
    "bluez5.roles" = [ "a2dp_sink" "a2dp_source" "hsp_ag" "hsp_hs" "hfp_ag" ];
  };
};
```

---

## Structural Refactoring Suggestions

### 18. 🔵 Move `brightnessctl` and `acpi` from Hosts to Shared Module

**Files:** Both hosts add laptop-specific packages.

**Action:** Create `modules/core/laptop.nix` with shared laptop configuration (brightnessctl, acpi, upower, etc.) and import it in both hosts.

---

### 19. 🔵 Refactor greetd Command for Readability

**File:** `modules/core/services.nix:37`

The tuigreet command line is a 200+ char inline string. Break it up:

```nix
let
  tuigreet-theme = "--theme 'container=black;border=green;text=white;...'";
in {
  services.greetd.settings.default_session.command =
    "${pkgs.tuigreet}/bin/tuigreet --time --asterisks --remember ${tuigreet-theme} --cmd start-hyprland";
}
```

---

### 20. 🔵 Add `nixpkgs.config.allowAliases = false`

**File:** `modules/core/system.nix` or `nixpkgs.nix`

```nix
nixpkgs.config.allowAliases = false;
```

This makes Nix error out if you reference a deprecated/renamed package, forcing you to use the current name. Catches bitrot early.

---

## Quick-Win Summary (Ordered by Effort)

| # | What | Effort | Impact | Type |
|---|------|--------|--------|------|
| 1 | Remove unused `superfile` input | 1 min | Cleaner lockfile | 🔴 |
| 2 | Fix `system` deprecation warning | 5 min | Cleaner eval | 🟡 |
| 3 | Conditional cardwire import | 5 min | Smaller closure | 🟡 |
| 6 | Make `username` configurable | 15 min | Safer install flow | 🔵 |
| 8 | Remove redundant kernel override | 1 min | Clarity | 🟡 |
| 9 | Deduplicate upower into core | 5 min | Less duplication | 🟡 |
| 12 | Add periodic GC | 5 min | Disk space savings | 🔵 |
| 7 | AdGuard password to agenix | 15 min | Security | 🔴 |
| 11 | Add hypridle | 10 min | Auto-suspend | 🟢 |
| 13 | Configure zram algorithm | 2 min | Better compression | 🔵 |
| 16 | LTS kernel for t480s | 2 min | Fewer reboots | 🔵 |
| 20 | `allowAliases = false` | 1 min | Catch deprecations | 🔵 |
| 18 | Shared laptop module | 20 min | Cleaner hosts | 🔵 |
| 10 | Verify DNS without resolved | 5 min | Avoid DNS breakage | 🟡 |
| 4 | Audit niche nix tools | 10 min | Less clutter | 🔵 |
| 5 | Add `gh` if needed | 2 min | GitHub CLI | 🔵 |
| 17 | Bluetooth audio config | 5 min | Better audio | 🟢 |
| 14 | Syncthing | 30 min | File sync | 🟢 |
| 15 | Printing | 15 min | Print support | 🟢 |
| 19 | Refactor greetd command | 5 min | Readability | 🔵 |
| _(skipped — overkill for a personal dotfiles repo)_ | | | | |
| 5 | Shared GPU module | 1 hr | Cleaner arch | 🔵 |
| 20 | Secrets management | 1-2 hrs | Encrypt secrets | 🟢 |
| 21 | NixOS tests | 2-3 hrs | Verification | 🟢 |
| 22 | Impermanence | 3-4 hrs | Purity (optional) | 🟢 |

---

---

## Profile-Specific Suggestions (Tailored to You)

**Your profile from pkgs + config:**
- Android/Flutter dev (SDK 34-36, NDK 28, Android Studio, Flutter, JDK)
- Polyglot dev (Rust, Go, C/C++, Python, JS/TS, Lua, Terraform)
- Content creator (OBS, Kdenlive)
- Mobile laptop user (t480s with tlp/throttled, lid suspend)
- Minimalist (greetd/tuigreet, no DE, Wayland-only)
- Privacy-conscious (AdGuard, hardened Zen Browser)
- Design picky (Gruvbox *everything*)

### For Android/Flutter Dev

1. **🔴 Add `scrcpy`** (`modules/home/packages/dev.nix`) — Mirror/control Android devices from desktop. Every Flutter dev needs this for testing on physical devices.

2. **🔴 Flutter version tracking** — Your `flutter` comes from nixpkgs-unstable. Flutter moves faster than nixpkgs. Add a `flutter` flake input pinned to a specific channel so `flutter doctor` doesn't complain:
   ```nix
   inputs.flutter.url = "github:flutter/flutter?ref=stable";
   ```

3. **🟢 `android-file-transfer`** — If you connect Android phones via USB for file transfer.

4. **🟢 Consider `vscode` with Dart/Flutter extensions** — Android Studio is heavy. VS Code is lighter and many Flutter devs prefer it:
   ```nix
   vscode-with-extensions.override {
     extensions = with vscode-extensions; [ dart-code.dart-code dart-code.flutter ];
   };
   ```

5. **🟢 Try `pkgs.buildFlutterApplication`** — For packaging Flutter apps reproducibly with Nix. You only have the SDK now.

### For Content Creation (OBS/Kdenlive)

6. **🟢 OBS with hardware encoding plugins** — You have OBS from `gui.nix` but no plugins for AMD/NVENC hardware encoding:
   ```nix
   obs-studio.override {
     plugins = with pkgs; [
       obs-studio-plugins.obs-vaapi
       obs-studio-plugins.obs-pipewire-audio-capture
     ];
   };
   ```

7. **🟢 `ffmpeg` with NVENC** — Your ROG has NVIDIA NVENC. The plain `ffmpeg` in `cli.nix` doesn't include it:
   ```nix
   environment.systemPackages = [ (ffmpeg-full.override { withNvidia = true; }) ];
   ```

8. **🟢 Add `audacity`** — OBS + Kdenlive cover recording/editing, but no dedicated audio editor for cleaning voiceovers.

### For Mobile Laptop (t480s)

9. **🟡 `throttled` vs `tlp` overlap** — Both manage CPU. `throttled` fixes the PSYS power limit on T480s, `tlp` manages governors. They can fight each other. Consider using only `throttled` (it has its own power management) or add config to prevent conflicts.

10. **🟢 `iwd` as NetworkManager WiFi backend** — Uses less power than `wpa_supplicant`:
    ```nix
    networking.networkmanager.wifi.backend = "iwd";
    ```

11. **🟢 Add `auto-cpufreq`** — Alternative to `tlp` with more aggressive battery optimization. Or keep `tlp` and add a systemd service for `powertop --auto-tune` on boot.

### For Privacy/Dev Workflow

12. **🟡 Verify DNS without `resolved`** — You disable `services.resolved` and set `nameservers = ["127.0.0.1"]`. If DNS breaks after suspend/resume, add:
    ```nix
    networking.networkmanager.dns = "default";
    ```

14. **🟢 Personal binary cache (Cachix/Attic)** — You have `nix-community` and `hyprland` caches but no private one. As a dev who rebuilds often, caching your own derivations saves hours. Especially useful for Android SDK/NDK which are huge and rarely change.

### Nix Power-User

15. **🟢 `nix.settings.cores = 0`** — Use all CPU cores on your ROG for faster builds.

16. **🟢 `boot.binfmt.registrations`** — If you ever cross-compile for aarch64 (ARM devices) from x86_64.

17. **🟢 Distributed builds** — Use t480s as a remote builder for ROG when idle (or vice versa).

---

## References

- [NixOS Manual](https://nixos.org/manual/nixos/stable/)
- [NixOS Wiki: Storage Optimization / GC](https://wiki.nixos.org/wiki/Storage_optimization)
- [NixOS Wiki: Impermanence](https://wiki.nixos.org/wiki/Impermanence)
- [NixOS & Flakes Book](https://nixos-and-flakes.thiscute.world/)
- [cachix/git-hooks.nix](https://github.com/cachix/git-hooks.nix)
- [Comparison of secret managing schemes](https://wiki.nixos.org/wiki/Comparison_of_secret_managing_schemes)

