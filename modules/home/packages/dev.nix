{ pkgs, ... }:
let
  androidSdk = pkgs.androidenv.composeAndroidPackages {
    platformVersions = [ "36" ];
    buildToolsVersions = [ "36.0.0" ];
    cmakeVersions = [ "3.22.1" ];
    includeNDK = true;
    ndkVersion = "28.2.13676358";
    includeEmulator = false;
    includeSystemImages = false;
  };
in
{
  home.packages = with pkgs; [
    nixd
    shfmt
    treefmt
    nixfmt
    gcc
    gdb
    gef
    cmake
    gnumake
    valgrind
    llvmPackages_20.clang-tools
    python3
    python312Packages.ipython
    flutter
    jdk
    mesa-demos # provides eglinfo for flutter doctor
    android-studio
    androidSdk.androidsdk
  ];

  home.sessionVariables = {
    ANDROID_SDK_ROOT = "${androidSdk.androidsdk}/libexec/android-sdk";
    ANDROID_HOME = "${androidSdk.androidsdk}/libexec/android-sdk";
    CHROME_EXECUTABLE = "zen-beta";
  };
}
