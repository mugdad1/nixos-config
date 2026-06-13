# GPU Switching (ASUS ROG G513RC)

This system uses **cardwire** (eBPF-based GPU blocker) + the hardware **MUX switch** to switch between AMD iGPU, NVIDIA dGPU, or both.

## Files

| File | Purpose |
|------|---------|
| `hosts/rog/default.nix` | Nix config: enables `services.cardwire`, asusd, `cardwire-apply-blocks` systemd service |
| `scripts/scripts/power-profile-menu.sh` | Rofi menu bound to `$mod + P` in Hyprland for GPU/profile switching |
| `flake.nix` | Adds `cardwire` flake input and its NixOS module |

## How It Works

### Hardware MUX Switch
File: `/sys/devices/platform/asus-nb-wmi/gpu_mux_mode`
- `0` — dGPU-only: NVIDIA drives the internal display directly
- `1` — Optimus: AMD iGPU drives the display, both GPUs available

Changing MUX mode requires a **reboot** — the value is stored in firmware NVRAM and applied at POST.

### cardwire (GPU Blocker)
- **integrated mode**: blocks NVIDIA dGPU via eBPF LSM
- **hybrid mode**: both GPUs unblocked
- **manual mode**: user controls which GPUs are blocked

Block states persist in `/var/lib/cardwire/gpu_state.json` but are NOT re-applied by cardwire on boot. A systemd oneshot service (`cardwire-apply-blocks`) re-applies them after `cardwired.service` starts.

## Modes

### AMD Only (Power Saver)
1. `cardwire set integrated` — blocks NVIDIA
2. If MUX is `0`: write `1` to `gpu_mux_mode` → reboot

### NVIDIA Only (Performance)
1. `cardwire set manual; cardwire gpu 1 --block` — blocks AMD
2. If MUX is `1`: write `0` to `gpu_mux_mode` → reboot

### Both (Hybrid)
1. `cardwire set hybrid` — both GPUs unblocked
2. No MUX change needed

## Manual Commands

```bash
# Check MUX state
cat /sys/devices/platform/asus-nb-wmi/gpu_mux_mode

# Set MUX mode
pkexec bash -c 'echo 1 > /sys/devices/platform/asus-nb-wmi/gpu_mux_mode'  # Optimus
pkexec bash -c 'echo 0 > /sys/devices/platform/asus-nb-wmi/gpu_mux_mode'  # dGPU

# Switch cardwire mode
pkexec cardwire set integrated   # AMD only
pkexec cardwire set hybrid       # Both
pkexec cardwire set manual       # Manual control
pkexec cardwire gpu 1 --block    # Block AMD (for NVIDIA only)

# Check status
cardwire get       # Current mode
cardwire list      # GPU list with block/default status
cat /sys/devices/platform/asus-nb-wmi/gpu_mux_mode  # MUX mode (0 or 1)
