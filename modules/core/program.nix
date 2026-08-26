{pkgs, ...}: {
  programs = {
    dconf.enable = true;
    zsh.enable = true;

    gnupg.agent = {
      enable = true;
      enableSSHSupport = false;
    };

    appimage.enable = true;

    # lets Mason-installed (dynamically linked) LSP servers/tools run
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
    aria2
    lz4
    ninja
    pkg-config
    poppler-utils
    tesseract
    imagemagick
    antiword
    pdftk
    qpdf
    ghostscript
  ];

  environment.variables = {
    JAVA_HOME = "${pkgs.jdk21}/lib/openjdk";
  };
}
