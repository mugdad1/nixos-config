{pkgs, ...}: {
  programs = {
    dconf.enable = true;
    zsh.enable = true;

    gnupg.agent = {
      enable = true;
      enableSSHSupport = true;
    };

    appimage.enable = true;

    nix-ld.enable = true;
  };
}
