# Headless laptop: lid closed, never sleep, power button does nothing
# (use the Gitea/Immich UI or ssh `reboot` instead of the button).
# Runs permanently on AC power with the battery removed, so we pin the
# governor to "performance" and skip all battery-aware power savings.
{lib, ...}: {
  services.logind.settings.Login = {
    HandleLidSwitch = "ignore";
    HandleLidSwitchExternalPower = "ignore";
    HandleLidSwitchDocked = "ignore";
    HandlePowerKey = "ignore";
    IdleAction = "ignore";
  };

  systemd.targets = {
    sleep.enable = false;
    suspend.enable = false;
    hibernate.enable = false;
    hybrid-sleep.enable = false;
  };

  powerManagement.cpuFreqGovernor = lib.mkDefault "performance";

  # Always on AC: nothing to tune, and a battery isn't present anyway.
  services.tlp.enable = lib.mkDefault false;
  services.power-profiles-daemon.enable = lib.mkDefault false;
}
