{pkgs, ...}: {
  security = {
    sudo = {
      enable = true;
      wheelNeedsPassword = true;
    };
    polkit.enable = true;
    rtkit.enable = true;

    pam.services.hyprlock = {};

    apparmor = {
      enable = true;
      killUnconfinedConfinables = true;
      packages = [pkgs.apparmor-profiles];
    };
  };
}
