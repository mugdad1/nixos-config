# ROG GPU Mode Switching Guide

How GPU switching works on this config: the ASUS hardware MUX is the real
switch, cardwire is the software layer, and the boot service ties them together.
This document explains the mechanism and every piece involved, including the
Omarchy (Arch) port that was built alongside this config.

## The hardware

ASUS ROG laptops with a MUX (like this one: AMD Radeon 680M + NVIDIA RTX 3050
Laptop GPU) expose a hardware display switch at:

```
/sys/devices/platform/asus-nb-wmi/gpu_mux_mode
```

- `1` = Optimus / iGPU mode — the internal panel is driven by the AMD iGPU, the
  NVIDIA dGPU is available for offload
- `0` = dGPU mode — the internal panel is driven by the NVIDIA dGPU directly and
  the AMD iGPU is effectively disconnected

Flipping the MUX is a **hardware** change: it only takes effect on the next
boot. In dGPU mode the system classifies as a "Desktop" (NVIDIA is the default
display), which unlocks cardwire's `manual` mode and per-GPU blocking.

## The problem: cardwire v0.12+

cardwire < v0.11 allowed `cardwire set manual` + per-GPU blocking on any system.
Since v0.12.0 the daemon classifies the system from the live GPU list and
refuses manual mode unless it is `Desktop`, or has 1 or 3+ GPUs:

```
Couldn't set mode to Manual, Manual mode is only available on Desktop or
system with either 1 GPU or 3+ GPUs
```

A MUX=1 laptop with both GPUs present classifies as `Laptop`, so manual mode is
refused while the iGPU is the display. This broke the old flow of "set manual +
block AMD before reboot": the set failed, `mode.json` stayed stale, and the boot
service re-flipped the MUX back to Optimus on the next boot.

## The fix

Never call `cardwire set manual` while in Laptop classification. Instead:

1. Persist the **desired** mode to `/etc/cardwire-desired-mode`
2. Flip the MUX and reboot
3. On boot, the apply-blocks service reads the desired mode and — now that the
   system is in dGPU mode and classifies as `Desktop` — runs `cardwire set
   manual` + blocks the AMD GPU, which finally succeed

## Mode map

| Profile           | Desired mode | MUX | cardwire (live)                 | cardwire (after boot) |
|-------------------|--------------|-----|---------------------------------|-----------------------|
| power-saver       | `amd`        | 1   | `integrated`                    | `integrated`          |
| balanced          | `hybrid`     | 1   | `hybrid`                        | `hybrid`              |
| performance       | `nvidia`     | 0   | (no change; reboot pending)     | `manual` + block AMD  |

## Pieces

### 1. Root helper (`power-profile-helper`, in `hosts/rog/default.nix`)

A `security.wrappers` root binary that gives the user scripts the two privileged
operations without a full passwordless sudo: writing the MUX and persisting the
desired mode.

```bash
case "$1" in
  cardwire-set)   $CARDWIRE set "$2" ;;
  cardwire-block) $CARDWIRE gpu "$2" --block ;;
  mux)            echo "$2" > "$MUX_PATH" ;;
  desired-mode)   echo "$2" > "$DESIRED_FILE" ;;
esac
```

### 2. The menu (`scripts/scripts/power-profile-menu.sh`)

Rofi menu bound to `SUPER + P` in `modules/home/hyprland/binds.nix`. It maps a
profile to asusctl + desired-mode + MUX:

```bash
nvidia-only)
    # cardwire v0.12+ refuses manual mode while the iGPU is live (Laptop
    # classification). Persist the intent + flip the MUX to dGPU, then reboot:
    # in dGPU mode the system classifies as Desktop and apply-blocks applies
    # manual + blocks AMD at boot.
    $HELPER desired-mode nvidia
    if [ "$mux" != "0" ]; then
        $HELPER mux 0
        notify-send -u normal "Profile" "NVIDIA Only — MUX flipped to dGPU. Rebooting..."
        sleep 2 && systemctl reboot
    fi
    ;;
```

### 3. The boot service (`cardwire-apply-blocks`, in `hosts/rog/default.nix`)

A `multi-user.target` oneshot that re-applies everything after reboot. Important
details:

- `wants = ["cardwired.service"]` (not `requires`) plus a wait loop: cardwired
  can fail its first start while NVIDIA device nodes are still being created,
  and systemd restarts it after 5s. With `requires` the apply-blocks job gets
  cancelled on that transient failure and never runs; `wants` + waiting for
  `cardwire list` fixes it.
- Desired mode wins over cardwire's own `mode.json`:

```bash
if [ -f "$DESIRED_FILE" ]; then
  MODE=$(cat "$DESIRED_FILE")
  case "$MODE" in
    amd)     cardwire set integrated 2>/dev/null || true ;;
    hybrid)  cardwire set hybrid 2>/dev/null || true ;;
    nvidia)  cardwire set manual 2>/dev/null || true
             AMD_ID=$(cardwire list --json | jq -r \
               "to_entries[] | select(.value.pci == \"$AMD_PCI\") | .value.id")
             [ -n "$AMD_ID" ] && cardwire gpu "$AMD_ID" --block 2>/dev/null || true ;;
  esac
elif [ -f "$MODE_FILE" ]; then
  # fall back to cardwire's own state
fi
```

- The MUX is set from the desired mode, not from `mode.json`:

```bash
case "$MODE" in
  amd|hybrid|integrated) [ "$CURRENT_MUX" != "1" ] && echo 1 > "$MUX_PATH" ;;
  nvidia|manual)         [ "$CURRENT_MUX" != "0" ] && echo 0 > "$MUX_PATH" ;;
esac
```

## Omarchy (Arch) port

The same mechanism was first built on the Omarchy install of this laptop, then
back-ported into this repo. If you are on Arch/Omarchy, this is the equivalent:

### Files

| Piece            | NixOS (this repo)                     | Omarchy                              |
|------------------|---------------------------------------|--------------------------------------|
| Root helper      | `power-profile-helper` (wrapper)      | `/usr/local/bin/cardwire-mux-switch` |
| Menu / trigger   | `power-profile-menu.sh` (rofi)        | power panel plugin `setProfile()`    |
| Boot service     | `cardwire-apply-blocks.service`       | `/etc/systemd/system/cardwire-apply-blocks.service` |
| Desired mode file| `/etc/cardwire-desired-mode`          | `/etc/cardwire-desired-mode`         |

### `cardwire-mux-switch` (root, run via `sudo`)

```bash
#!/usr/bin/env bash
set -euo pipefail

MUX=/sys/devices/platform/asus-nb-wmi/gpu_mux_mode
DESIRED=/etc/cardwire-desired-mode

case "${1:-}" in
  amd)     [ -f "$MUX" ] && echo 1 > "$MUX"; echo "amd" > "$DESIRED" ;;
  hybrid)  [ -f "$MUX" ] && echo 1 > "$MUX"; echo "hybrid" > "$DESIRED" ;;
  nvidia)  [ -f "$MUX" ] && echo 0 > "$MUX"; echo "nvidia" > "$DESIRED" ;;
  *)       echo "usage: cardwire-mux-switch <amd|hybrid|nvidia>" >&2; exit 1 ;;
esac

cat "$DESIRED"
```

### sudoers rule

```bash
# /etc/sudoers.d/cardwire-mux
mugdad ALL=(root) NOPASSWD: /usr/local/bin/cardwire-mux-switch
```

### `power-profile-switch.sh` (user, called by the bar panel)

Maps a power profile to asusctl + desired mode + MUX, reboots only when the MUX
actually changes, and prompts via a clickable notification instead of an
automatic reboot:

```bash
sudo /usr/local/bin/cardwire-mux-switch "$gpu_mode"

if [ "$CURRENT_MUX" != "$DESIRED_MUX" ]; then
  omarchy-notification-send --exec "systemctl reboot" \
    -g "󰜥" -u normal \
    "GPU Mode" "Switched to ${gpu_mode^^} — click to reboot now (ignore to cancel)"
fi
```

The panel's `setProfile()` in the cloned `mugdad.power` plugin runs this script
with `["<script>", ac|battery, <profile>]` as its command.

### The boot service (same logic as NixOS)

Identical `cardwire-apply-blocks` script as in `hosts/rog/default.nix`, installed
at `/usr/local/bin/cardwire-apply-blocks` with a systemd oneshot using `Wants=`
+ the wait loop.

## Verification

After switching modes and rebooting:

```bash
cat /etc/cardwire-desired-mode   # amd | hybrid | nvidia
cat /sys/devices/platform/asus-nb-wmi/gpu_mux_mode   # 1 | 0
cardwire get                     # Integrated | Hybrid | Manual
cardwire list --json             # check "blocked" flags:
#   performance: NVIDIA launchable=true, AMD blocked=true
#   power-saver: AMD launchable=true, NVIDIA blocked=true
#   balanced:    both launchable=true
powerprofilesctl get
asusctl profile get
```

Check the boot service ran cleanly:

```bash
systemctl status cardwire-apply-blocks
journalctl -b -u cardwire-apply-blocks -u cardwired
```
