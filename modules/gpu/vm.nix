{ lib, pkgs, config, ... }:
with lib;
let
  cfg = config.drivers.vm;
in {
  options.drivers.vm = {
    enable = mkEnableOption "Enable VM guest services";
  };

  config = mkIf cfg.enable {
    services.qemuGuest.enable = true;
    services.spice-vdagentd.enable = true;
  };
}
