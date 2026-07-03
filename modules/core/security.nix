{pkgs, lib, ...}: {
  security = {
    polkit.enable = true;
    rtkit.enable = true;

    pam.services.hyprlock = {};

    wrappers.pkexec = {
      enable = lib.mkForce true;
      setuid = true;
      owner = "root";
      group = "root";
      source = "${pkgs.polkit.bin}/bin/pkexec";
    };
  };
}
