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
    # Fine-grained RTD3: the 3050 drops to D3cold when nothing holds it and
    # `nvidia-offload` wakes it on demand. NixOS then sets
    # NVreg_DynamicPowerManagement=0x02 and adds the udev rule that flips
    # power/control to `auto`. HDMI hangs off this GPU, so that is the one
    # path to re-test after a driver bump.
    powerManagement.finegrained = true;
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

  # Linux 7.3 starts kernel threads in a nullfs root, so nvidia's probe thread
  # cannot open the PCI config file and silently turns RTD3 off
  # (NVIDIA/open-gpu-kernel-modules#1507): /proc/driver/nvidia/gpus/*/power says
  # "Not supported" and the 3050 never leaves D0. Re-probing from process
  # context after the modules are loaded restores it; the udev bind rule then
  # flips power/control to auto.
  systemd.services.nvidia-rtd3-rebind = {
    description = "Re-probe the NVIDIA GPU so runtime D3 is enabled";
    wantedBy = ["multi-user.target"];
    after = ["systemd-modules-load.service"];
    before = ["display-manager.service"];
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
    };
    script = ''
      drv=/sys/bus/pci/drivers/nvidia
      dev=0000:01:00.0
      if [ -e "$drv/$dev" ]; then
        echo "$dev" > "$drv/unbind"
        echo "$dev" > "$drv/bind"
      fi
    '';
  };

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
