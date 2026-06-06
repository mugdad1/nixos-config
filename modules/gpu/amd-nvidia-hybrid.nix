{ lib, pkgs, config, ... }:
let
  cfg = config.drivers.amd-nvidia-hybrid;
in {
  options.drivers.amd-nvidia-hybrid = {
    enable = lib.mkEnableOption "Enable AMD iGPU + NVIDIA dGPU (Prime offload)";
    amdgpuBusId = lib.mkOption {
      type = lib.types.str;
      default = "PCI:5:0:0";
      description = "PCI Bus ID for AMD GPU";
    };
    nvidiaBusId = lib.mkOption {
      type = lib.types.str;
      default = "PCI:1:0:0";
      description = "PCI Bus ID for NVIDIA dGPU";
    };
  };

  config = lib.mkIf cfg.enable {
    environment.systemPackages = with pkgs; [
      amdgpu_top
      nvtopPackages.full
      rocmPackages.amdsmi
      rocmPackages.rocminfo
      rocmPackages.rocm-smi
    ];

    services.xserver.videoDrivers = [ "nvidia" ];

    hardware = {
      graphics.extraPackages = with pkgs; [
        mesa
        libva
        libva-utils
      ];

      nvidia = {
        modesetting.enable = true;
        open = true;
        nvidiaSettings = true;
        package = config.boot.kernelPackages.nvidiaPackages.stable;
        powerManagement.enable = true;
        powerManagement.finegrained = true;

        prime = {
          offload = {
            enable = true;
            enableOffloadCmd = true;
          };
          amdgpuBusId = cfg.amdgpuBusId;
          nvidiaBusId = cfg.nvidiaBusId;
        };
      };
    };
  };
}
