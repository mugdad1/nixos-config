{
  config,
  lib,
  pkgs,
  ...
}: let
  # ── GPU mode switch ────────────────────────────────────────────────────────
  #
  # His ask, 2026-10-22: "i want a switch that switch it from intel only then
  # both and nvidia only". ASUS shipped that as Armoury Crate on his old ROG;
  # HP ships nothing for Linux and this chassis has no MUX, so the switch is
  # built here out of the three things that actually work on Wayland:
  #
  #   intel  — iGPU renders, nvidia modules unloaded, dGPU powers down.
  #   hybrid — iGPU renders, dGPU loaded and available per-app via nvidia-offload.
  #   nvidia — dGPU renders, iGPU still scans out the internal panel (no MUX,
  #            so the panel cannot be moved off the iGPU).
  #
  # The mode is a file under /var/lib/victus read by the sway session wrapper in
  # modules/desktop/services.nix (which sets WLR_DRM_DEVICES before exec sway).
  # Changing it takes effect at the next login; module load/unload happens
  # immediately so battery draw changes without a reboot.
  gpuMode = pkgs.writeShellScriptBin "gpu-mode" ''
    set -eu
    export PATH=${lib.makeBinPath [pkgs.kmod pkgs.coreutils]}:$PATH
    mode="''${1:-}"
    case "$mode" in
      intel|hybrid|nvidia) ;;
      *)
        echo "usage: gpu-mode intel|hybrid|nvidia" >&2
        exit 1
        ;;
    esac
    if [ "$(id -u)" -ne 0 ]; then
      exec sudo "$0" "$@"
    fi
    install -d -m 0755 /var/lib/victus
    printf '%s\n' "$mode" > /var/lib/victus/gpu-mode.tmp
    chmod 0644 /var/lib/victus/gpu-mode.tmp
    mv /var/lib/victus/gpu-mode.tmp /var/lib/victus/gpu-mode
    case "$mode" in
      intel)
        # Refuses (cleanly) if something still holds the modules.
        modprobe -r nvidia_drm nvidia_modeset nvidia_uvm nvidia 2>/dev/null || true
        ;;
      *)
        modprobe nvidia nvidia_uvm nvidia_modeset nvidia_drm 2>/dev/null || true
        ;;
    esac
    echo "GPU mode: $mode — log out and back in to apply."
    echo "  intel  iGPU only, dGPU off"
    echo "  hybrid iGPU now, dGPU on demand: nvidia-offload <command>"
    echo "  nvidia dGPU renders everything (iGPU still drives the panel)"
  '';
in {
  imports = [
    ./hardware-configuration.nix
    ../../modules/core
    ../../modules/desktop
  ];

  # Intel UHD (Alder Lake) is the display GPU and the VAAPI/OpenCL target.
  hardware.graphics = {
    extraPackages = with pkgs; [
      intel-media-driver
      intel-compute-runtime
    ];
  };

  # ── NVIDIA RTX 3050 Laptop (GA107) ─────────────────────────────────────────
  # Open kernel modules (Ampere is supported; he picked open over proprietary).
  # PRIME offload, not sync: the panel is wired to the iGPU on this chassis, so
  # "sync" would just burn power. `nvidia-offload` comes from enableOffloadCmd.
  #
  # BUS IDs ARE ASSUMED and are the one thing to check on real hardware if the
  # driver fails to attach: `lspci | grep -E 'VGA|3D'` should give 00:02.0 for
  # the Intel UHD and 01:00.0 for the RTX 3050. Rewrite both lines below if they
  # differ (01:00.0 vs 02:00.0 varies by model).
  services.xserver.videoDrivers = ["nvidia"];

  hardware.nvidia = {
    open = true;
    modesetting.enable = true;
    powerManagement.enable = true;
    powerManagement.finegrained = false;
    nvidiaSettings = true;

    prime = {
      offload.enable = true;
      offload.enableOffloadCmd = true;
      intelBusId = "PCI:0:2:0";
      nvidiaBusId = "PCI:1:0:0";
    };
  };

  # The nvidia module only loads its kernel modules at boot when X is enabled
  # (see nixpkgs hardware/video/nvidia.nix), and this host is Wayland-only, so
  # load them explicitly. Without this, `nvidia-offload` only works after
  # somebody modprobes by hand.
  boot.kernelModules = ["nvidia" "nvidia_uvm" "nvidia_modeset" "nvidia_drm"];

  # Generic tuning only. Deliberately NOT carried over from the t480s:
  # mem_sleep_default=deep (Alder Lake uses s2idle), the Elan TrackPoint quirk,
  # the ThinkPad battery-threshold unit, throttled/tlp, or nixos-hardware's
  # ThinkPad module. Thermal handling is stock.
  boot.kernelParams = [
    "nowatchdog"
    "psi=1"
    "rootflags=noatime"
    "fbcon=nodefer"
  ];

  services.throttled.enable = false;
  services.tlp.enable = false;
  services.power-profiles-daemon.enable = true;

  environment.systemPackages = [
    gpuMode
    pkgs.tmux
  ];

  # Hybrid is the default when no mode has been chosen yet; `f` only creates the
  # file, so a chosen mode always survives rebuilds.
  systemd.tmpfiles.rules = [
    "d /var/lib/victus 0755 root root -"
    "f /var/lib/victus/gpu-mode 0644 root root - hybrid"
  ];

  services.logind.settings.Login = {
    HandleLidSwitch = "suspend";
    HandleLidSwitchExternalPower = "ignore";
  };

  environment.sessionVariables = {
    LIBVA_DRIVER_NAME = "iHD";
  };
}
