{ pkgs, config, ... }:
{
  imports = [
    ./hardware-configuration.nix
    ./../../modules/core
  ];

  environment.systemPackages = with pkgs; [
    acpi
    brightnessctl
    lm_sensors
  ];

  services = {
    power-profiles-daemon.enable = true;

    upower = {
      enable = true;
      percentageLow = 20;
      percentageCritical = 10;
      percentageAction = 5;
      criticalPowerAction = "HybridSleep";
    };

    thermald.enable = true;

    thinkfan.enable = true;
  };

  hardware = {
    cpu.intel.updateMicrocode = true;

    trackpoint = {
      enable = true;
      speed = 200;
      sensitivity = 200;
      emulateWheel = true;
    };
  };

  boot = {
    kernelModules = [
      "acpi_call"
      "thinkpad_acpi"
    ];
    extraModulePackages = with config.boot.kernelPackages; [ acpi_call ];
  };

  # Battery charge threshold at 80% for longevity
  systemd.services.set-battery-charge-threshold = {
    description = "Set battery charge threshold to 80%";
    wantedBy = [ "multi-user.target" ];
    serviceConfig.Type = "oneshot";
    script = ''
      echo 80 > /sys/class/power_supply/BAT0/charge_control_end_threshold 2>/dev/null || true
    '';
  };

  systemd.services.set-power-profile-on-boot = {
    description = "Set power profile based on AC state at boot";

    wantedBy = [ "power-profiles-daemon.service" ];
    after = [ "power-profiles-daemon.service" ];
    partOf = [ "power-profiles-daemon.service" ];

    serviceConfig.Type = "oneshot";

    script = ''
      if [ "$(cat /sys/class/power_supply/AC/online 2>/dev/null || echo 0)" = "1" ]; then
        ${pkgs.power-profiles-daemon}/bin/powerprofilesctl set balanced
      else
        ${pkgs.power-profiles-daemon}/bin/powerprofilesctl set power-saver
      fi
    '';
  };

  # Automatically switch power profiles on AC/Battery
  services.udev.extraRules = ''
    SUBSYSTEM=="power_supply", ATTR{type}=="Mains", ATTR{online}=="1", RUN+="${pkgs.power-profiles-daemon}/bin/powerprofilesctl set balanced"
    SUBSYSTEM=="power_supply", ATTR{type}=="Mains", ATTR{online}=="0", RUN+="${pkgs.power-profiles-daemon}/bin/powerprofilesctl set power-saver"
  '';
}
