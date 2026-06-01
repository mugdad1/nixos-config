{ lib, pkgs, config, ... }:
with lib;
let
  cfg = config.drivers.intel;
in {
  options.drivers.intel = {
    enable = mkEnableOption "Enable Intel GPU drivers";
  };

  config = mkIf cfg.enable {
    environment.systemPackages = with pkgs; [
      intel-gpu-tools
    ];

    hardware.graphics.extraPackages = with pkgs; [
      intel-media-driver
      intel-vaapi-driver
      libvdpau-va-gl
      vpl-gpu-rt
    ];
  };
}
