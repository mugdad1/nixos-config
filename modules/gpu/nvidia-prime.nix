{ lib, pkgs, config, ... }:
with lib;
let
  cfg = config.drivers.nvidia-prime;
in {
  options.drivers.nvidia-prime = {
    enable = mkEnableOption "Enable NVIDIA Optimus (Intel iGPU + NVIDIA dGPU)";
    intelBusID = mkOption {
      type = types.str;
      default = "PCI:0:2:0";
      description = "PCI Bus ID for Intel iGPU";
    };
    nvidiaBusID = mkOption {
      type = types.str;
      default = "PCI:1:0:0";
      description = "PCI Bus ID for NVIDIA dGPU";
    };
  };

  config = mkIf cfg.enable {
    services.xserver.videoDrivers = [ "nvidia" ];

    hardware.nvidia = {
      modesetting.enable = true;
      powerManagement.enable = true;
      powerManagement.finegrained = true;
      open = false;
      nvidiaSettings = true;
      package = config.boot.kernelPackages.nvidiaPackages.stable;

      prime = {
        offload = {
          enable = true;
          enableOffloadCmd = true;
        };
        intelBusId = cfg.intelBusID;
        nvidiaBusId = cfg.nvidiaBusID;
      };
    };
  };
}
