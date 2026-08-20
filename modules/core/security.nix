{pkgs, lib, ...}: {
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
      killUnconfinedConfinables = true;
      packages = [pkgs.apparmor-profiles];
    };
  };

  systemd.services.apparmor = {
    reloadIfChanged = lib.mkForce false;
    serviceConfig.ExecReload = lib.mkForce [];
  };

  environment.etc."apparmor/parser.conf".text = ''
    write-cache
    Optimize=compress-fast
    cache-loc /var/cache/apparmor/
  '';

  systemd.coredump.settings = {
    Coredump = {
      Storage = "none";
      ProcessSizeMax = 0;
    };
  };
}
