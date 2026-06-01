{ lib, pkgs, config, ... }:
with lib;
let
  cfg = config.drivers.amdgpu;
in {
  options.drivers.amdgpu = {
    enable = mkEnableOption "Enable AMD GPU drivers";
  };

  config = mkIf cfg.enable {
    environment.systemPackages = with pkgs; [
      amdgpu_top
      nvtopPackages.amd
      rocmPackages.amdsmi
      rocmPackages.rocminfo
      rocmPackages.rocm-smi
    ];

    hardware.graphics.extraPackages = with pkgs; [
      mesa
      libva
      libva-utils
    ];
  };
}
