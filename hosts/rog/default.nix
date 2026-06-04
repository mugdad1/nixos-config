{ pkgs, config, lib, ... }:
{
  imports = [
    ./hardware-configuration.nix
    ./../../modules/core
    ./../../modules/rog
  ];

  environment.systemPackages = with pkgs; [
    acpi
    brightnessctl
  ];

  services = {
    power-profiles-daemon.enable = true;

    upower = {
      enable = true;
      percentageLow = 20;
      percentageCritical = 5;
      percentageAction = 3;
      criticalPowerAction = "PowerOff";
    };
  };

  powerManagement.cpuFreqGovernor = "powersave";

  boot.kernelParams = [ "pci=realloc" ];
  boot.kernelModules = [ "acpi_call" "r8169" ];
  boot.extraModulePackages = with config.boot.kernelPackages; [ acpi_call ];

  # ROG-specific monitor config — both internal displays with same settings
  home-manager.users.mugdad = {
    wayland.windowManager.hyprland.settings.monitor = lib.mkForce [
      "eDP-1,1920x1080@60,0x0,1.2"
      "eDP-2,1920x1080@60,0x0,1.2"
    ];
  };

  systemd.tmpfiles.rules = [
    "d /var/lib/gpu-mode 0755 root root"
  ];

  systemd.services.restore-gpu-mode = {
    description = "Restore GPU mode from last session";
    after = [ "supergfxd.service" ];
    wants = [ "supergfxd.service" ];
    wantedBy = [ "multi-user.target" ];
    serviceConfig.Type = "oneshot";
    script = ''
      state_file="/var/lib/gpu-mode/state"
      if [ -f "$state_file" ]; then
        mode=$(cat "$state_file")
        ${pkgs.supergfxctl}/bin/supergfxctl -m "$mode" 2>/dev/null || true
      else
        ${pkgs.supergfxctl}/bin/supergfxctl -m Integrated 2>/dev/null || true
      fi
    '';
  };
}
