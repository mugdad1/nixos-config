{
  lib,
  variables,
  ...
}: {
  nix = {
    # Dedup runs nightly instead of on every build path (better on spinning HDDs).
    optimise.automatic = true;

    # Keep big rebuilds from starving the desktop.
    daemonCPUSchedPolicy = "batch";
    daemonIOSchedClass = "best-effort";
    daemonIOSchedPriority = 6;

    settings = {
      auto-optimise-store = false;
      builders-use-substitutes = true;
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
    "kernel.kptr_restrict" = 2;
    "kernel.dmesg_restrict" = 1;
    "kernel.sysrq" = 0;
    "kernel.yama.ptrace_scope" = 1;
    "kernel.unprivileged_bpf_disabled" = 1;

    "net.ipv4.tcp_syncookies" = 1;
    "net.ipv4.conf.all.accept_redirects" = 0;
    "net.ipv4.conf.default.accept_redirects" = 0;
    "net.ipv4.conf.all.secure_redirects" = 0;
    "net.ipv4.conf.default.secure_redirects" = 0;
    "net.ipv4.conf.all.accept_source_route" = 0;
    "net.ipv4.conf.default.accept_source_route" = 0;
    "net.ipv4.conf.all.rp_filter" = 1;
    "net.ipv4.conf.default.rp_filter" = 1;

    "net.ipv4.tcp_fastopen" = 3;
    "net.ipv4.tcp_congestion_control" = "bbr";
    "net.core.default_qdisc" = "cake";

    # Every host is zram-only; compressed swap has no seek cost.
    "vm.swappiness" = 133;
    "vm.page-cluster" = 0;
    "vm.vfs_cache_pressure" = 50;
  };

  time.timeZone = lib.mkDefault variables.timezone;

  # The stock pool resolves to the ISP's NTP box (212.138.170.134), which
  # never answers, so every host sat at "System clock synchronized: no".
  # Servers are pinned by IP on purpose: asus's RTC has lost power twice and
  # come up at 2019, and then DoT/DoH certificates fail, which kills blocky,
  # which kills DNS, which would kill name-based NTP too. Plain NTP by IP
  # breaks that deadlock.
  services.timesyncd = {
    servers = ["162.159.200.1" "216.239.35.0"];
    fallbackServers = ["162.159.200.123" "216.239.35.4"];
  };

  i18n.defaultLocale = lib.mkDefault variables.locale;
  nixpkgs.config.allowUnfree = lib.mkDefault true;
  nixpkgs.config.android_sdk.accept_license = true;
  system.stateVersion = "26.05";
}
