{ pkgs, ... }:
let
  # Android SDK for Flutter APK builds (Noor app)
  androidSdk = (pkgs.androidenv.composeAndroidPackages {
    platformVersions = ["34" "35" "36"];
    buildToolsVersions = ["34.0.0" "35.0.0" "36.0.0"];
    includeNDK = false;
    includeEmulator = false;
    includeSystemImages = false;
  }).androidsdk;
in {
  documentation.nixos.enable = false;

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
    androidSdk
    flutter
    heimdall
    usbutils
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
    supertuxkart
  ];


  environment.variables = {
    JAVA_HOME = "${pkgs.jdk21}/lib/openjdk";
    ANDROID_HOME = "${androidSdk}/libexec/android-sdk";
    ANDROID_SDK_ROOT = "${androidSdk}/libexec/android-sdk";
  };
}
