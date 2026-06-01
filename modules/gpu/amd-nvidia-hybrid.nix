{ lib, pkgs, config, ... }:
with lib;
let
  cfg = config.drivers.amd-nvidia-hybrid;
in {
  options.drivers.amd-nvidia-hybrid = {
    enable = mkEnableOption "Enable AMD iGPU + NVIDIA dGPU (Prime offload)";
    amdgpuBusId = mkOption {
      type = types.str;
      default = "PCI:5:0:0";
      description = "PCI Bus ID for AMD GPU";
    };
    nvidiaBusId = mkOption {
      type = types.str;
      default = "PCI:1:0:0";
      description = "PCI Bus ID for NVIDIA dGPU";
    };
  };

  config = mkIf cfg.enable {
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
