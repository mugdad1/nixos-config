{pkgs, ...}: {
  security = {
    sudo = {
      enable = true;
      wheelNeedsPassword = true;
    };
    polkit.enable = true;
    rtkit.enable = true;

    pam.services.hyprlock = {};
  };
}
