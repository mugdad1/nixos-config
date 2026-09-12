{pkgs, ...}: {
  security = {
    sudo = {
      enable = true;
      wheelNeedsPassword = true;
    };
    polkit = {
      enable = true;
      enablePkexecWrapper = true;
      extraConfig = ''
        polkit.addRule(function(action, subject) {
          if (subject.isInGroup("wheel") && (
           action.id == "org.freedesktop.login1.reboot" ||
           action.id == "org.freedesktop.login1.reboot-multiple-sessions" ||
           action.id == "org.freedesktop.login1.power-off" ||
           action.id == "org.freedesktop.login1.power-off-multiple-sessions"
          ))
          { return polkit.Result.YES; }
        })
      '';
    };
    rtkit.enable = true;

    pam.services.hyprlock = {};

    apparmor = {
      enable = true;
      enableCache = true;
      killUnconfinedConfinables = true;
      packages = [pkgs.apparmor-profiles];
    };
  };

  systemd.coredump.settings = {
    Coredump = {
      Storage = "none";
      ProcessSizeMax = 0;
    };
  };
}
