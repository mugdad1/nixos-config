{pkgs, ...}: {
  documentation.nixos.enable = false;

  programs = {
    dconf.enable = true;
    fish.enable = true;

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
    # Every host gets opencode from here; grandpa imports no home-manager stack.
    opencode
    cachix
    nftables # `sudo nft list ruleset` — the firewall is nftables

    # adb / fastboot for his phone. androidSdk/flutter were dropped 2026-10-13.
    android-tools
    usbutils

    # Hardware identification — every host must be able to describe itself.
    pciutils
    dmidecode
    fastfetch
    hwinfo
    lshw
    smartmontools
    nvme-cli
    ethtool
    lm_sensors

    aria2
    lz4
    ninja
    pkg-config
    libusb1
    cryptopp
    poppler-utils
    tesseract
    imagemagick
    antiword
    pdftk
    qpdf
    ghostscript
    trash-cli
    onefetch
  ];
}
