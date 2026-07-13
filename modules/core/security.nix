{pkgs, ...}: {
  security = {
    sudo = {
      enable = true;
      wheelNeedsPassword = false;
    };
    polkit.enable = true;
    rtkit.enable = true;

    pam.services.hyprlock = {};
  };
}
