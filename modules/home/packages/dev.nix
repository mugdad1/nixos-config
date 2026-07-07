{ pkgs, lib, host, ... }: let
  androidSdk = pkgs.androidenv.composeAndroidPackages {
    platformVersions = [ "34" "35" "36" ];
    buildToolsVersions = [ "34.0.0" "35.0.0" "36.0.0" ];
    cmakeVersions = ["3.22.1"];
    includeNDK = true;
    ndkVersion = "28.2.13676358";
    includeEmulator = false;
    includeSystemImages = false;
  };
in {
  home.packages =
    with pkgs; [
      ## Nix
      nixd
      nixfmt
      shfmt
      treefmt

      ## C / C++
      gcc
      gdb
      gef
      cmake
      gnumake
      valgrind
      llvmPackages_latest.clang-tools

      ## Python
      python3
      python312Packages.ipython
    ]
    ++ lib.optionals (host == "rog") [
      ## Android / Flutter
      flutter
      jdk
      mesa-demos
      android-studio
      androidSdk.androidsdk
    ];

  home.sessionVariables =
    { CHROME_EXECUTABLE = "zen-beta"; }
    // lib.optionalAttrs (host == "rog") {
      ANDROID_SDK_ROOT = "${androidSdk.androidsdk}/libexec/android-sdk";
      ANDROID_HOME = "${androidSdk.androidsdk}/libexec/android-sdk";
    };
}
