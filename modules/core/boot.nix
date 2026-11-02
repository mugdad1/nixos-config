{
  pkgs,
  lib,
  ...
}: let
  gruvbox = (import ../../lib/gruvbox.nix).raw;
in {
  boot = {
    loader = {
      systemd-boot = {
        enable = true;
        editor = false;
        configurationLimit = 10;
        # Count boots and fall back to the previous generation after repeated
        # failures; useful on victus where a bad GPU/kernel boot is otherwise
        # a manual rescue.
        bootCounting.enable = true;
      };

      efi.canTouchEfiVariables = true;
    };

    # Kernel tuning, decided 2026-11-02 ("optimize my systems"):
    #   page_poison=1     gone — zeroes every freed page for a benefit that is
    #                     not worth the cost; init_on_free supersedes it.
    #   page_alloc.shuffle=1  gone — per-allocation page-list shuffling is
    #                     allocator hot-path work for memory-layout entropy,
    #                     not speed.
    #   randomize_kstack_offset=on  gone — already the compiled default on
    #                     x86_64 (RANDOMIZE_KSTACK_OFFSET_DEFAULT=y), so the
    #                     parameter changed nothing.
    # slab_nomerge is KEPT: measurements put it within noise of merged slabs,
    # so it costs nothing measurable and retains the hardening.
    kernelParams = lib.mkBefore [
      "quiet"
      "slab_nomerge"
    ];

    kernelPackages = pkgs.linuxPackages_latest;
    supportedFilesystems = ["ntfs"];
    tmp.cleanOnBoot = true;
  };

  systemd.tmpfiles.rules = [
    "D /tmp 1777 root root 1d"
    "D /var/tmp 1777 root root 7d"
  ];

  console.colors = [
    gruvbox.bg0 # 0  black
    gruvbox.red # 1  red
    gruvbox.green # 2  green
    gruvbox.yellow # 3  yellow
    gruvbox.blue # 4  blue
    gruvbox.purple # 5  magenta
    gruvbox.aqua # 6  cyan
    gruvbox.gray # 7  light gray
    gruvbox.dark_gray # 8  dark gray
    gruvbox.bright_red # 9  light red
    gruvbox.bright_green # 10 light green
    gruvbox.bright_yellow # 11 light yellow
    gruvbox.bright_blue # 12 light blue
    gruvbox.bright_purple # 13 light magenta
    gruvbox.bright_aqua # 14 light cyan
    gruvbox.fg # 15 white
  ];
}
