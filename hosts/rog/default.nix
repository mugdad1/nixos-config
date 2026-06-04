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
}
