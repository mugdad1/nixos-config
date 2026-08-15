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
      package = pkgs.jdk21;
    };
  };

  environment.systemPackages = with pkgs; [
    android-tools
    heimdall
    usbutils
    lz4
    ninja
    pkg-config
  ];

  environment.variables = {
    JAVA_HOME = "${pkgs.jdk21}/lib/openjdk";
  };
}
