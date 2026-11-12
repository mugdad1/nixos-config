# HP Victus 15 — i5-12th gen + RTX 3050 Laptop. The panel is wired to the
# Intel iGPU, so there is no MUX: `gpu-mode` decides what renders, not what
# scans out. Cardwire blocks dGPU access in intel mode.
{
  config,
  lib,
  pkgs,
  ...
}: let
  # cardwire 0.12.3 omits sqlite from buildInputs and fails to link.
  cardwire = pkgs.cardwire.overrideAttrs (old: {
    buildInputs = (old.buildInputs or []) ++ [pkgs.sqlite];
  });

  # Writes /var/lib/victus/gpu-mode, read by the session wrapper in
  # modules/desktop/services.nix. Renderer changes apply at next login.
  gpuMode = pkgs.writeShellScriptBin "gpu-mode" ''
    set -eu
    export PATH=${lib.makeBinPath [pkgs.kmod pkgs.coreutils cardwire]}:$PATH
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
    # Keep the driver loaded in every mode; Cardwire blocks at the syscall
    # level, which is what lets the dGPU reach D3cold.
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

  # Super+P menu: Intel only -> power-saver, hybrid -> balanced,
  # NVIDIA only -> performance.
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
    # Only change the power profile once the GPU mode actually applied.
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

  # patchelf >= 0.18 relocates .dynamic of these non-PIE NVIDIA binaries into a
  # read-only segment, so ld.so segfaults before main. 0.15.2 keeps it writable.
  nvidiaPatchelf = pkgs.patchelf.overrideAttrs (_old: rec {
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

  hardware.graphics = {
    extraPackages = with pkgs; [
      intel-media-driver
      intel-compute-runtime
    ];
  };

  services.xserver.videoDrivers = ["nvidia"];

  hardware.nvidia = {
    open = true;

    # Match the 615.78.08 branch CachyOS runs on this box. Only the userland
    # outputs are rebuilt: pristine binaries are re-linked with nvidiaPatchelf.
    package = config.boot.kernelPackages.nvidiaPackages.latest.overrideAttrs (old: {
      postInstall =
        (
          if (old.postInstall or null) != null
          then old.postInstall
          else ""
        )
        + ''
          for i in nvidia-smi nvidia-cuda-mps-server nvidia-cuda-mps-control \
                   nvidia-debugdump nvidia-powerd; do
            if [ -e "$bin/origBin/$i" ]; then
              install -Dm755 "$bin/origBin/$i" "$bin/bin/$i"
              # Two calls, rpath first: combining them can move .dynamic into
              # a read-only LOAD.
              ${nvidiaPatchelf}/bin/patchelf \
                --set-rpath "$out/lib:$libPath" \
                "$bin/bin/$i"
              ${nvidiaPatchelf}/bin/patchelf \
                --interpreter "$(cat $NIX_CC/nix-support/dynamic-linker)" \
                "$bin/bin/$i"
            fi
          done
        '';
    });

    modesetting.enable = true;
    powerManagement.enable = true;
    # Ampere notebooks already default to fine-grained RTD3.
    powerManagement.finegrained = false;
    nvidiaSettings = false;

    # Decode on the Intel iGPU.
    videoAcceleration = false;

    # Keep the suspend VRAM image off RAM-backed /tmp.
    moduleParams.nvidia.NVreg_TemporaryFilePath = "/var/tmp";

    # No MUX: the panel is wired to the iGPU. Offload only.
    prime = {
      offload.enable = true;
      offload.enableOffloadCmd = true;
      intelBusId = "PCI:0:2:0";
      nvidiaBusId = "PCI:1:0:0";
    };
  };

  # Cardwire keeps the driver loaded and blocks opens of the dGPU device nodes,
  # so the GPU can stay in D3cold.
  services.cardwired = {
    enable = true;
    package = cardwire;
    settings = {
      auto_apply_gpu_state = true;
      experimental_nvidia_block = true;
      external_display_auto_switch = true;
    };
  };

  systemd.services.cardwired.environment.RUST_LOG = "warn";

  boot.kernelModules = [
    "nvidia"
    "nvidia_uvm"
    "nvidia_modeset"
    "nvidia_drm"
  ];

  # Re-apply the saved mode to cardwired at boot.
  systemd.services.victus-gpu-mode = {
    description = "Apply the saved GPU mode to Cardwire";
    wantedBy = ["multi-user.target"];
    after = ["cardwired.service"];
    wants = ["cardwired.service"];
    before = ["greetd.service"];
    path = [cardwire pkgs.coreutils];
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
      for _ in {1..30}; do
        if cardwire set "$target"; then
          exit 0
        fi
        sleep 1
      done
      echo "victus-gpu-mode: could not set Cardwire mode to $target" >&2
      exit 1
    '';
  };

  boot.kernelParams = [
    "nowatchdog"
    "psi=1"
    "rootflags=noatime"
    "fbcon=nodefer"
    # USB enumeration on the Type-C port fails for some low-speed devices.
    "usbcore.old_scheme_first=1"
    "usbcore.use_both_schemes=1"
    "usbcore.initial_descriptor_timeout=10000"
    "usbcore.autosuspend=-1"
  ];

  services.throttled.enable = false;
  services.tlp.enable = false;
  services.power-profiles-daemon.enable = true;

  # HP's own ACPI charge-mode methods, not TLP thresholds.
  services.victus.batteryChargeLimit = {
    enable = true;
    stopAt = 85;
    resumeAt = 82;
  };

  environment.systemPackages = [
    gpuMode
    gpuMenu
    pkgs.nvtopPackages.full
    pkgs.tmux
    pkgs.ollama-cuda
  ];

  # Local model server on the RTX 3050. Listens on 127.0.0.1:11434.
  # OLLAMA_CONTEXT_LENGTH must equal limit.context in
  # modules/home/apps/opencode.nix (16384 on both).
  services.ollama = {
    enable = true;
    package = pkgs.ollama-cuda;
    environmentVariables = {
      OLLAMA_CONTEXT_LENGTH = "16384";
      OLLAMA_MAX_LOADED_MODELS = "1"; # one resident model, never two
      OLLAMA_NUM_PARALLEL = "1"; # slots multiply the KV cache
      # Generation here is KV-cache bound, not weight bound; q8_0 halves the
      # cache so more layers stay on the die, and it requires flash attention.
      OLLAMA_FLASH_ATTENTION = "1";
      OLLAMA_KV_CACHE_TYPE = "q8_0";
    };
    loadModels = [
      "qwen3.5:4b"
      "ministral-3:8b"
      "gemma4:e4b"
      "mimo-v2.6"
      "nemotron-3-nano:4b"
    ];
  };

  # `f` only creates the file, so a chosen mode survives rebuilds.
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
