{ pkgs, ... }:
{
  services = {
    gvfs.enable = true;

    gnome = {
      tinysparql.enable = true;
      gnome-keyring.enable = true;
    };

    dbus.enable = true;
    fstrim = {
      enable = true;
      interval = "daily";
    };
    fwupd.enable = true;

    # needed for GNOME services outside of GNOME Desktop
    dbus.packages = [ pkgs.gcr pkgs.gnome-settings-daemon ];

    logind.settings.Login = {
      # don’t shutdown when power button is short-pressed
      HandlePowerKey = "ignore";

      # ignore lid close
      HandleLidSwitch = "ignore";
      HandleLidSwitchExternalPower = "ignore";
      HandleLidSwitchDocked = "ignore";
    };

    udisks2.enable = true;
  };
}
