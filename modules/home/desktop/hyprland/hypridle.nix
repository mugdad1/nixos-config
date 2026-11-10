{lib, ...}: {
  services.hypridle = {
    enable = true;
    systemdTarget = "graphical-session.target";

    settings = {
      general = {
        # hyprctl dispatch takes a Lua dispatcher expression in 0.57+.
        lock_cmd = "pidof hyprlock || hyprlock";
        after_sleep_cmd = ''hyprctl dispatch 'hl.dsp.dpms({ action = "enable" })' '';
        ignore_dbus_inhibit = false;
      };

      listener = [
        {
          timeout = 900;
          on-timeout = "hyprlock";
        }
        {
          timeout = 1200;
          on-timeout = ''hyprctl dispatch 'hl.dsp.dpms({ action = "disable" })' '';
          on-resume = ''hyprctl dispatch 'hl.dsp.dpms({ action = "enable" })' '';
        }
      ];
    };

    # hypridle is installed for both sessions' home profile, but its commands
    # are Hyprland-only (hyprlock + `hyprctl`). The HM module only conditions
    # the unit on WAYLAND_DISPLAY, so gate it on the desktop the session
    # wrapper exported (modules/desktop/services.nix) — otherwise the Sway
    # session would start it and fail to lock / toggle DPMS.
  };

  systemd.user.services.hypridle.Unit.ConditionEnvironment = lib.mkForce [
    "WAYLAND_DISPLAY"
    "XDG_CURRENT_DESKTOP=Hyprland"
  ];
}
