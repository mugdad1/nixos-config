{ pkgs, lib, host, ... }: let
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
      androidsdk
    ];

  home.sessionVariables =
    { CHROME_EXECUTABLE = "zen-beta"; }
    // lib.optionalAttrs (host == "rog") {
      ANDROID_SDK_ROOT = "${pkgs.androidsdk}/libexec/android-sdk";
      ANDROID_HOME = "${pkgs.androidsdk}/libexec/android-sdk";
    };
}
