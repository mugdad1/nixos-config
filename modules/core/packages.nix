{pkgs, ...}: let
  # sops — the CLI for editing secrets/fleet.sops.yaml (2026-10-18, his
  # "add it fast"). It is NOT needed to DECRYPT: that is done at activation by
  # sops-install-secrets, which reads the age key from /var/lib/sops-nix/key.txt
  # and needs no CLI at all. This is for the interactive half — `sops
  # secrets/fleet.sops.yaml` opens the ciphertext in $EDITOR and re-encrypts on
  # save, which is the only sane way to add or rotate a value.
  #
  # It was absent from ALL THREE hosts until today, which made the README's
  # "adding a secret" instructions un-runnable without a detour through
  # `nix shell` — and a bootstrap step that does not work on the box it is
  # written for is the kind of doc rot this repo just spent a day deleting.
  #
  # Declared in modules/core so every host gets it from one place (the two
  # servers import no home-manager stack, so a systemPackage is the only route
  # that covers them). It needs the age key to be useful: with the key on all
  # three hosts (row 121) it works everywhere.
  sops = pkgs.sops;
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
    # ─── opencode — REMOVED 2026-10-31 on his word ──────────────────────────
    # It was here (his ask 2026-10-30, one line for all three hosts) so every
    # host got v2 from nixpkgs. He no longer wants it, so the package is gone
    # from the fleet; the binary disappears on the next switch. Restore by
    # putting `opencode` back in this list.
    # opencode

    cachix
    nftables # `sudo nft list ruleset` — the firewall is nftables
    sops
    filen-cli
    # adb / fastboot — STILL NEEDED for his phone. This is the only Android
    # bit that stays; everything below it that was toolchain-related is off.
    android-tools
    # ─── DISABLED 2026-10-13 on his word (see note at top of file) ──────────
    # androidSdk
    # flutter
    # heimdall
    usbutils
    # ─── hardware identification — EVERY host, by his instruction ──────────
    # "any new host must have these". A box that cannot describe its own
    # board, RAM, disks and NIC gets its specs guessed instead of read; that
    # is exactly what happened to grandpa's RAM and motherboard on 2026-10-27.
    # All of these are read-only probes, and all are tiny next to a desktop
    # closure. dmidecode needs root (SMBIOS); the rest do not.
    # usbutils above and lm_sensors below belong to the same set, they just
    # predate this list.
    pciutils # lspci — GPU, NIC, SATA, and what is on which bus
    dmidecode # board model, RAM slots/speed, chassis (sudo)
    fastfetch # the one-screen summary
    hwinfo # deep probe: disks, NICs, buses
    lshw # structured hardware tree
    smartmontools # smartctl -a /dev/sdX — disk health
    nvme-cli # nvme smart-log /dev/nvme0
    ethtool # link speed, driver, wake-on-lan
    # lm-sensors: DECLARED, NOT INHERITED. It has no NixOS module in current
    # nixpkgs at all (neither services.lm_sensors nor hardware.temperatures
    # exists - checked against this flake's nixpkgs 2026-10-21), so this
    # systemPackages line IS the configuration. On 2026-10-21 the t480s was
    # the only host of the three missing the sensors binary, and the reason
    # was that the other two had it only TRANSITIVELY: nix-store -q --tree on
    # the thinkcentre showed lm-sensors-3.6.2-bin in the system path with
    # nothing in the repo naming it, so a package-set change on any host could
    # have dropped it silently. Here, every host says so on purpose.
    # wiki decisions.md row 184.
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
