# Headless laptop: lid closed, never sleep, power button does nothing
# (use the Gitea UI or ssh `reboot` instead of the button).
# Runs permanently on AC power with the battery removed and NO chassis, so
# cooling is compromised: pin the governor to "powersave", run thermald, and
# skip all battery-aware power savings.
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

  # No chassis = weak cooling: powersave keeps clocks (and temps) down.
  # 2026-09-21: package hit 98C (crit 100C) at load ~1.5 on performance.
  # intel_pstate offers ONLY performance/powersave (verified live, no
  # "balanced" governor exists), so "balanced" = powersave + EPP
  # balance_performance (boosts on demand, rests at idle).
  powerManagement.cpuFreqGovernor = lib.mkDefault "powersave";

  systemd.services.epp-balanced = {
    description = "Set Intel EPP to balance_performance (the 'balanced' mode)";
    after = ["multi-user.target"];
    wantedBy = ["multi-user.target"];
    serviceConfig.Type = "oneshot";
    script = ''
      for f in /sys/devices/system/cpu/cpufreq/policy*/energy_performance_preference; do
        [ -f "$f" ] && echo balance_performance > "$f"
      done
    '';
  };

  # Intel thermal daemon as a safety net (trips before the 100C crit).
  services.thermald.enable = true;

  # Always on AC: nothing to tune, and a battery isn't present anyway.
  services.tlp.enable = lib.mkDefault false;
  services.power-profiles-daemon.enable = lib.mkDefault false;
}
