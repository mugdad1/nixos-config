{
  pkgs,
  lib,
  ...
}: let
  gruvbox = (import ../../modules/gruvbox.nix).raw;
in {
  boot = {
    loader = {
      systemd-boot = {
        enable = true;
        enableEditor = false;
        maxGenerations = 10;
      };

      efi.canTouchEfiVariables = true;
    };

    kernelParams = lib.mkBefore [
      "quiet"
    ];

    kernelPackages = pkgs.linuxPackages_latest;
    supportedFilesystems = ["ntfs"];
  };

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
