{pkgs, ...}: {
  programs = {
    dconf.enable = true;
    zsh.enable = true;

    gnupg.agent = {
      enable = true;
      enableSSHSupport = false;
    };

    appimage.enable = true;

    nix-ld.enable = true;

    java = {
      enable = true;
      package = pkgs.jdk17;
    };
  };

  environment.systemPackages = with pkgs; [
    android-tools
  ];
}
