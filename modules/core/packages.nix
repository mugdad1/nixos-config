{pkgs, ...}: let
  # filen-cli 0.2.9 — the Rust build (filen-rs), NOT nixpkgs' own 0.0.36,
  # which is the old Go implementation. Declared in ../../pkgs/filen-cli.nix;
  # the reasoning (musl-static vs gnu, prebuilt vs source) is written there.
  #
  # Declared HERE, in modules/core, so BOTH hosts get it from one place — this
  # is shared systemPackages, not a home-manager entry, which is why it lands on
  # the ThinkCentre too (that host imports no home-manager stack at all).
  #
  # This replaced a hand-run `curl | bash` into ~/.filen-cli on 2026-10-15,
  # which is exactly the shape a reinstall loses: the binary lived outside the
  # flake, and its installer only appends to bash/zsh profiles, so on a fish
  # login shell it printed "No shell profile file found" and left `filen`
  # unreachable. Declarative, it needs no PATH entry at all — /run/current-system/sw/bin
  # carries it on both machines.
  filen-cli = pkgs.callPackage ../../pkgs/filen-cli.nix {};
  # ─── DISABLED 2026-10-13 on his word ───────────────────────────────────────
  # Android SDK for Flutter APK builds (Noor app). He does not use Flutter or
  # Android Studio — only adb/fastboot for his phone, and android-tools (the
  # package that provides those) is STILL ENABLED below, so nothing about phone
  # debugging is lost.
  #
  # Commented out, not deleted — uncomment to re-enable. Note this binding was
  # referenced in THREE places, all now commented out together: the
  # systemPackages entry below, AND the ANDROID_HOME / ANDROID_SDK_ROOT env
  # vars. Leaving the env vars active would have kept the SDK in the closure
  # even after dropping it from systemPackages, so the weight would not have
  # moved. This was several GB (flutter + dart + androidsdk + openjdk).
  #
  # androidSdk =
  #   (pkgs.androidenv.composeAndroidPackages {
  #     platformVersions = ["34" "35" "36"];
  #     buildToolsVersions = ["34.0.0" "35.0.0" "36.0.0"];
  #     includeNDK = false;
  #     includeEmulator = false;
  #     includeSystemImages = false;
  #   }).androidsdk;
in {
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
    cachix
    filen-cli
    # adb / fastboot — STILL NEEDED for his phone. This is the only Android
    # bit that stays; everything below it that was toolchain-related is off.
    android-tools
    # ─── DISABLED 2026-10-13 on his word (see note at top of file) ──────────
    # androidSdk
    # flutter
    # heimdall
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
    onefetch
    # supertuxkart   # DISABLED 2026-10-13 on his word. Commented, not deleted.
    # whisper-cpp    # DISABLED 2026-10-13 on his word. Also dropped the ~1.2G
    #                # of voice/model data it pulled (mbrola-voices, models-dev).
    # btrfs-assistant  # DISABLED 2026-10-13 on his word. Commented, not deleted.
  ];

  # ─── DISABLED 2026-10-13 on his word ───────────────────────────────────────
  # These pointed at ${androidSdk}, so they MUST be off alongside the package —
  # env vars keep a store path alive in the closure regardless of systemPackages.
  # environment.variables = {
  #   ANDROID_HOME = "${androidSdk}/libexec/android-sdk";
  #   ANDROID_SDK_ROOT = "${androidSdk}/libexec/android-sdk";
  # };
}
