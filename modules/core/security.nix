{pkgs, ...}: {
  security = {
    sudo = {
      enable = true;
      wheelNeedsPassword = true;
    };
    polkit = {
      enable = true;
      enablePkexecWrapper = true;
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
