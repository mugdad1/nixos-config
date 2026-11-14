{
  config,
  lib,
  pkgs,
  ...
}: let
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

  boot.kernelModules = [
    "nvidia"
    "nvidia_uvm"
    "nvidia_modeset"
    "nvidia_drm"
  ];

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

  # Panel on the iGPU, HDMI on the dGPU, no MUX: tell the compositor about both
  # DRM nodes so an external display works from login.
  services.desktop.intelPrimaryDrm = true;

  # HP's own ACPI charge-mode methods, not TLP thresholds.
  services.victus.batteryChargeLimit = {
    enable = true;
    stopAt = 85;
    resumeAt = 82;
  };

  environment.systemPackages = [
    pkgs.nvtopPackages.full
    pkgs.tmux
  ];

  services.logind.settings.Login = {
    HandleLidSwitch = "suspend";
    HandleLidSwitchExternalPower = "ignore";
  };

  environment.sessionVariables = {
    LIBVA_DRIVER_NAME = "iHD";
  };
}
