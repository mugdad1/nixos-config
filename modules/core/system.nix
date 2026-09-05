{
  lib,
  variables,
  ...
}: {
  nix = {
    settings = {
      auto-optimise-store = true;
      builders-use-substitutes = true;
      download-buffer-size = 524288000;
      experimental-features = [
        "nix-command"
        "flakes"
      ];
      max-jobs = "auto";
      substituters = lib.mkAfter [
        "https://nix-community.cachix.org"
        "https://hyprland.cachix.org"
        "https://ghostty.cachix.org"
      ];
      trusted-public-keys = lib.mkAfter [
        "nix-community.cachix.org-1:mB9FSh9qf2dCimDSUo8Zy7bkq5CX+/rkCWyvRCYg3Fs="
        "hyprland.cachix.org-1:a7pgxzMz7+chwVL3/pzj6jIBMioiJM7ypFP8PwtkuGc="
        "ghostty.cachix.org-1:QB389yTa6gTyneehvqG58y0WnHjQOqgnA+wBnpWWxns="
      ];
    };
  };

  services.btrfs.autoScrub = {
    enable = true;
    interval = "weekly";
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
    "vm.swappiness" = 10;
    "vm.vfs_cache_pressure" = 50;
  };

  time.timeZone = lib.mkDefault variables.timezone;
  i18n.defaultLocale = lib.mkDefault variables.locale;
  nixpkgs.config.allowUnfree = lib.mkDefault true;
  system.stateVersion = "26.05";
}
