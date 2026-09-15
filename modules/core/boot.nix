{
  pkgs,
  lib,
  variables,
  ...
}: let
  theme = (import ../../lib/theme.nix variables).raw;
in {
  boot = {
    loader = {
      systemd-boot = {
        enable = true;
        editor = false;
        configurationLimit = 10;
      };

      efi.canTouchEfiVariables = true;
    };

    kernelParams = lib.mkBefore [
      "quiet"
      "slab_nomerge"
      "page_poison=1"
      "page_alloc.shuffle=1"
      "randomize_kstack_offset=on"
      "debugfs=off"
    ];

    kernelPackages = pkgs.linuxPackages_latest;
    supportedFilesystems = ["ntfs"];
    tmp.cleanOnBoot = true;
  };

  systemd.tmpfiles.rules = [
    "D /tmp 1777 root root 1d"
    "D /var/tmp 1777 root root 7d"
    "d /var/cache/tuigreet 0755 greeter greeter"
  ];

  console.colors = [
    theme.bg0 # 0  black
    theme.red # 1  red
    theme.green # 2  green
    theme.yellow # 3  yellow
    theme.blue # 4  blue
    theme.purple # 5  magenta
    theme.aqua # 6  cyan
    theme.gray # 7  light gray
    theme.dark_gray # 8  dark gray
    theme.bright_red # 9  light red
    theme.bright_green # 10 light green
    theme.bright_yellow # 11 light yellow
    theme.bright_blue # 12 light blue
    theme.bright_purple # 13 light magenta
    theme.bright_aqua # 14 light cyan
    theme.fg # 15 white
  ];
}
