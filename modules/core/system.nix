{
  lib,
  variables,
  ...
}: {
  nix = {
    # Store dedup moved OFF the build path 2026-11-02 (optimisation pass):
    # auto-optimise-store ran a dedup pass over every build's output, and on
    # grandpa's spinning HDD that was measurable I/O for no interactive gain.
    # The nightly timer does the same work at 03:45 instead.
    optimise.automatic = true;
    # Keep big rebuilds from starving the desktop. Defaults are
    # other/best-effort/4; batch + priority 6 still finishes the build but
    # leaves the UI responsive. (NixOS already sets max-jobs = "auto" and
    # cores = 0, so there is nothing to raise there.)
    daemonCPUSchedPolicy = "batch";
    daemonIOSchedClass = "best-effort";
    daemonIOSchedPriority = 6;
    settings = {
      auto-optimise-store = false;
      builders-use-substitutes = true;
      # download-buffer-size removed 2026-11-02: Nix >=2.33 fixed the
      # underlying issue and upstream now recommends the 1 MiB default over
      # the old 500 MB cargo-cult value (this pin ships Nix 2.35.3).
      experimental-features = [
        "nix-command"
        "flakes"
      ];
      max-jobs = "auto";
      substituters = lib.mkAfter [
        "https://nix-community.cachix.org"
      ];
      trusted-public-keys = lib.mkAfter [
        "nix-community.cachix.org-1:mB9FSh9qf2dCimDSUo8Zy7bkq5CX+/rkCWyvRCYg3Fs="
      ];
    };
  };

  security.protectKernelImage = true;

  boot.kernelModules = ["tcp_bbr"];

  boot.kernel.sysctl = {
    # Kernel hardening
    "kernel.kptr_restrict" = 2;
    "kernel.dmesg_restrict" = 1;
    "kernel.sysrq" = 0;
    "kernel.yama.ptrace_scope" = 1;
    "kernel.unprivileged_bpf_disabled" = 1;

    # Network hardening
    "net.ipv4.tcp_syncookies" = 1;
    "net.ipv4.conf.all.accept_redirects" = 0;
    "net.ipv4.conf.default.accept_redirects" = 0;
    "net.ipv4.conf.all.secure_redirects" = 0;
    "net.ipv4.conf.default.secure_redirects" = 0;
    "net.ipv4.conf.all.accept_source_route" = 0;
    "net.ipv4.conf.default.accept_source_route" = 0;
    "net.ipv4.conf.all.rp_filter" = 1;
    "net.ipv4.conf.default.rp_filter" = 1;

    # TCP optimization
    "net.ipv4.tcp_fastopen" = 3;
    "net.ipv4.tcp_congestion_control" = "bbr";
    "net.core.default_qdisc" = "cake";

    # VM tuning
    # Every host is zram-only (swapDevices = [] on all three). Kernel docs
    # suggest >100 when swap is ~2x faster than the filesystem and 133 in that
    # example; 60 (the old default) and 10 both left zram idle.
    "vm.swappiness" = 133;
    # Compressed-RAM swap has no seek cost, so readahead is wasted work.
    "vm.page-cluster" = 0;
    "vm.vfs_cache_pressure" = 50;
  };

  time.timeZone = lib.mkDefault variables.timezone;
  i18n.defaultLocale = lib.mkDefault variables.locale;
  nixpkgs.config.allowUnfree = lib.mkDefault true;
  nixpkgs.config.android_sdk.accept_license = true;
  system.stateVersion = "26.05";
}
