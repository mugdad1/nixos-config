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

  # Console display: on when someone is at the box, auto-blank when idle.
  # Blanking the VT powers down the i915 eDP pipeline (killing the backlight
  # too), and any keypress unblanks immediately — no separate backlight
  # service, so the screen is usable whenever a human is present.
  boot.kernelParams = lib.mkAfter ["consoleblank=60"];

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
