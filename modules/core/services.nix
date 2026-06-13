{pkgs, ...}: {
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
    dbus.packages = [
      pkgs.gcr
      pkgs.gnome-settings-daemon
    ];

    logind.settings.Login = {
      # don’t shutdown when power button is short-pressed
      HandlePowerKey = "ignore";

      # ignore lid close
      HandleLidSwitch = "ignore";
      HandleLidSwitchExternalPower = "ignore";
      HandleLidSwitchDocked = "ignore";
    };

    udisks2.enable = true;

    greetd = {
      enable = true;
      settings = {
        default_session = {
          command = "${pkgs.tuigreet}/bin/tuigreet --time --asterisks --remember --theme 'container=black;border=green;text=white;prompt=yellow;time=gray;action=blue;button=cyan;title=light_blue;greet=light_green;input=white' --cmd start-hyprland";
          user = "greeter";
        };
      };
    };
  };

  systemd.tmpfiles.rules = [
    "d /var/cache/tuigreet 0755 greeter greeter"
  ];

  zramSwap.enable = true;

  boot.kernel.sysctl."vm.swappiness" = 10;
}
