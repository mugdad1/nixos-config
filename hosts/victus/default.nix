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
  #   intel  — iGPU renders, Cardwire blocks dGPU access, GPU stays in D3cold.
  #   hybrid — iGPU renders, dGPU available per-app via nvidia-offload.
  #   nvidia — iGPU scans out and renders the desktop; dGPU remains available
  #            for apps via PRIME offload. There is no MUX, and wlroots cannot
  #            use the dGPU as primary while eDP-1 is wired to the iGPU:
  #            forcing that gives a black screen, sometimes with only a cursor.
  #
  # The mode is a file under /var/lib/victus read by the sway session wrapper in
  # modules/desktop/services.nix (which sets WLR_DRM_DEVICES before exec sway).
  # Cardwire applies the block/unblock immediately; the renderer change takes
  # effect at the next login.
  gpuMode = pkgs.writeShellScriptBin "gpu-mode" ''
    set -eu
    export PATH=${lib.makeBinPath [pkgs.kmod pkgs.coreutils pkgs.cardwire]}:$PATH
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
    # Keep the driver loaded in every mode; Cardwire blocks device access at
    # the syscall level, which is what lets the dGPU reach D3cold without the
    # fragile modprobe -r that sway/apps used to prevent.
    modprobe nvidia 2>/dev/null || true
    modprobe nvidia_uvm 2>/dev/null || true
    modprobe nvidia_modeset 2>/dev/null || true
    modprobe nvidia_drm 2>/dev/null || true

    case "$mode" in
      intel)
        if ! cardwire set integrated; then
          echo "gpu-mode: cardwired is not reachable; the block will be applied at next boot" >&2
          exit 1
        fi
        ;;
      hybrid | nvidia)
        if ! cardwire set hybrid; then
          echo "gpu-mode: cardwired is not reachable; the block will be applied at next boot" >&2
          exit 1
        fi
        ;;
    esac
    echo "GPU mode: $mode — log out and back in to apply."
    echo "  intel  iGPU only, dGPU off"
    echo "  hybrid iGPU now, dGPU on demand: nvidia-offload <command>"
    echo "  nvidia iGPU drives the panel, dGPU available for PRIME offload"
  '';

  # Super+P menu, ported from the old ROG power-profile-menu: power-saver =
  # Intel only, balanced = both GPUs, performance = NVIDIA only. There is no
  # ASUS MUX on this chassis. "NVIDIA only" keeps the iGPU driving the panel
  # and exposes the dGPU for PRIME offload; a true dGPU scanout is not possible.
  # The renderer change takes effect at the next login, while Cardwire's
  # block/unblock is applied immediately.
  gpuMenu = pkgs.writeShellScriptBin "gpu-menu" ''
    set -eu
    export PATH=${lib.makeBinPath [
      gpuMode
      pkgs.rofi
      pkgs.libnotify
      pkgs.power-profiles-daemon
      pkgs.coreutils
    ]}:$PATH
    mode="$(cat /var/lib/victus/gpu-mode 2>/dev/null || echo hybrid)"
    case "$mode" in
      intel) selected=0 ;;
      nvidia) selected=2 ;;
      *) selected=1 ;;
    esac
    intel="<span color='#98971a'>󰾆 </span>Intel only"
    both="<span color='#d79921'>󰾅 </span>Both (hybrid)"
    nvidia="<span color='#cc241d'>󰓅 </span>NVIDIA only"
    chosen="$(printf '%s\n' "$intel" "$both" "$nvidia" | \
      rofi -dmenu -i -markup-rows -p 'GPU mode' \
        -theme "$HOME/.config/rofi/powermenu-theme.rasi" \
        -theme-str 'window {width: 320px;} listview {columns: 1;}' \
        -selected-row "$selected")" || exit 0
    case "$chosen" in
      *Intel*) target=intel; profile=power-saver ;;
      *Both*) target=hybrid; profile=balanced ;;
      *NVIDIA*) target=nvidia; profile=performance ;;
      *) exit 0 ;;
    esac
    # The GPU mode is the source of truth: only change the power profile after
    # it actually applied. The mapping is the Super+P contract:
    #   Intel only -> power-saver, Both -> balanced, NVIDIA only -> performance.
    if out="$(gpu-mode "$target" 2>&1)"; then
      if pp_out="$(powerprofilesctl set "$profile" 2>&1)"; then
        notify-send -u normal "GPU mode: $target" "Power profile: $profile. Log out and back in to apply."
      else
        notify-send -u normal "GPU mode: $target" "Power profile not changed: $pp_out"
      fi
    else
      notify-send -u critical "GPU mode failed" "$out"
    fi
  '';

  # patchelf >= 0.18 relocates the .dynamic section of these non-PIE NVIDIA
  # executables into a read-only PT_LOAD. glibc writes the DT_DEBUG pointer into
  # .dynamic before main runs, so they die with SIGSEGV inside ld.so's dl_main
  # (this is why nvidia-smi and nvidia-cuda-mps-control were broken while nvtop
  # read both GPUs fine). 0.15.2 keeps .dynamic writable; it is used below to
  # re-link the pristine copies from origBin/ that the driver build keeps.
  nvidiaPatchelf = pkgs.patchelf.overrideAttrs (old: rec {
    version = "0.15.2";
    src = pkgs.fetchurl {
      url = "https://github.com/NixOS/patchelf/releases/download/${version}/patchelf-${version}.tar.gz";
      hash = "sha256-DWn63A3rY/5GZlu9qZ6gIJy4G7PWDPVRCE+dvsB8u2w=";
    };
  });
in {
  imports = [
    ./battery-charge-limit.nix
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
  # If the BIOS ever offers a graphics/MUX mode, leave it on Hybrid — the
  # gpu-mode switch assumes both GPUs are visible to the OS.
  #
  # BUS IDs ARE ASSUMED and are the one thing to check on real hardware if the
  # driver fails to attach: `lspci | grep -E 'VGA|3D'` should give 00:02.0 for
  # the Intel UHD and 01:00.0 for the RTX 3050. Rewrite both lines below if they
  # differ (01:00.0 vs 02:00.0 varies by model).
  services.xserver.videoDrivers = ["nvidia"];

  hardware.nvidia = {
    open = true;

    # Stable is 595.104.02. Only its userland outputs are rebuilt here (the
    # kernel module comes from the untouched passthru.open and stays cached):
    # re-install each pristine executable and re-apply interpreter + RPATH with
    # nvidiaPatchelf, instead of the corrupted copies from the normal build.
    package = config.boot.kernelPackages.nvidiaPackages.stable.overrideAttrs (old: {
      postInstall = (if (old.postInstall or null) != null then old.postInstall else "") + ''
        for i in nvidia-smi nvidia-cuda-mps-server nvidia-cuda-mps-control \
                 nvidia-debugdump nvidia-powerd; do
          if [ -e "$bin/origBin/$i" ]; then
            install -Dm755 "$bin/origBin/$i" "$bin/bin/$i"
            ${nvidiaPatchelf}/bin/patchelf \
              --interpreter "$(cat $NIX_CC/nix-support/dynamic-linker)" \
              --set-rpath "$out/lib:$libPath" \
              "$bin/bin/$i"
          fi
        done
      '';
    });

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

  # Cardwire owns dGPU access now. Unlike unloading the modules (which this
  # chassis made fragile: sway and apps hold /dev/nvidia* and renderD128), it
  # keeps the driver loaded and blocks opens of the dGPU device nodes with an
  # eBPF/LSM program. The GPU can then stay in D3cold and nothing can wake it.
  # It is generic: no ASUS WMI or MUX is involved, and Integrated mode is
  # supported exactly on laptops like this one where the dGPU is an offload
  # GPU behind the iGPU.
  services.cardwired = {
    enable = true;
    settings = {
      auto_apply_gpu_state = true;
      experimental_nvidia_block = true; # also block /dev/nvidiactl etc.
      external_display_auto_switch = true; # HDMI is wired to the dGPU
    };
  };

  # Cardwire does not unload drivers, so keep the whole stack loaded for it to
  # see and block. The NVIDIA driver runtime-suspends the GPU to D3cold when
  # nothing is using it.
  boot.kernelModules = [
    "nvidia"
    "nvidia_uvm"
    "nvidia_modeset"
    "nvidia_drm"
  ];

  # Apply the mode stored in /var/lib/victus/gpu-mode to cardwired at boot.
  # `gpu-mode` applies it immediately for the running session; this makes the
  # choice survive a reboot without relying on cardwire's own persistence.
  systemd.services.victus-gpu-mode = {
    description = "Apply the saved GPU mode to Cardwire";
    wantedBy = ["multi-user.target"];
    after = ["cardwired.service"];
    wants = ["cardwired.service"];
    before = ["greetd.service"];
    path = with pkgs; [cardwire coreutils];
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
    };
    restartIfChanged = false;
    script = ''
      mode="$(cat /var/lib/victus/gpu-mode 2>/dev/null || echo hybrid)"
      case "$mode" in
        intel) target=integrated ;;
        hybrid | nvidia) target=hybrid ;;
        *) target=hybrid ;;
      esac
      for _ in 1 2 3 4 5; do
        if cardwire set "$target"; then
          exit 0
        fi
        sleep 1
      done
      echo "victus-gpu-mode: could not set Cardwire mode to $target" >&2
      exit 1
    '';
  };

  # Generic tuning only. Deliberately NOT carried over from the t480s:
  # mem_sleep_default=deep (Alder Lake uses s2idle), the Elan TrackPoint quirk,
  # the ThinkPad battery-threshold unit, throttled/tlp, or nixos-hardware's
  # ThinkPad module. Thermal handling is stock.
  boot.kernelParams = [
    "nowatchdog"
    "psi=1"
    "rootflags=noatime"
    "fbcon=nodefer"
    # USB enumeration on the Type-C port (bus 3 port 1) fails with
    # "device descriptor read/64, error -71" for some low-speed devices.
    # Give enumeration more time and try both init schemes; also keep
    # autosuspend off while probing.
    "usbcore.old_scheme_first=1"
    "usbcore.use_both_schemes=1"
    "usbcore.initial_descriptor_timeout=10000"
    "usbcore.autosuspend=-1"
  ];

  services.throttled.enable = false;
  services.tlp.enable = false;
  services.power-profiles-daemon.enable = true;

  # Use HP's own ACPI charge-mode methods instead of TLP thresholds.  The test
  # on board 8A4F stopped charging at 89% (SBCO 0x05 -> GBCO 0x04) and resumed
  # it with SBCO 0x00.  The daemon is in battery-charge-limit.nix.
  services.victus.batteryChargeLimit = {
    enable = true;
    stopAt = 80;
    resumeAt = 77;
  };

  environment.systemPackages = [
    gpuMode
    gpuMenu
    pkgs.nvtopPackages.full
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
