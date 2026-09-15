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

  # Headless: the internal panel has nothing to show, blank the console VT after
  # 60s idle (i915 suspends the eDP pipeline on blank so the backlight dies too).
  # i8042.nokbd kills the internal PS/2 keyboard (no one types on a headless
  # box); USB keyboards still work for emergencies.
  boot.kernelParams = lib.mkAfter ["consoleblank=60" "i8042.nokbd"];

  # Belt-and-braces: yank the backlight straight off at boot via sysfs.
  # No-op (exit 0) when no backlight device exists, e.g. screen removed.
  systemd.services.backlight-off = {
    description = "Turn off internal display backlight (headless server)";
    after = ["multi-user.target"];
    wantedBy = ["multi-user.target"];
    serviceConfig.Type = "oneshot";
    script = ''
      for d in /sys/class/backlight/*; do
        [ -e "$d" ] || continue
        [ -f "$d/bl_power" ] && echo 4 > "$d/bl_power"
      done
      exit 0
    '';
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
