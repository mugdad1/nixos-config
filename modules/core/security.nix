{pkgs, lib, ...}: {
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
      killUnconfinedConfinables = false;
      packages = [pkgs.apparmor-profiles];
    };
  };

  systemd.services.apparmor = {
    reloadIfChanged = lib.mkForce false;
    serviceConfig.ExecReload = lib.mkForce [];
  };
}
