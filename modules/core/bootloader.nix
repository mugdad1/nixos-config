{
  pkgs,
  lib,
  ...
}: let
  gruvbox = (import ../../modules/gruvbox.nix).raw;

  wallpaper = ../../wallpapers/otherWallpaper/nixos/nixos.png;
in {
  boot = {
    loader = {
      limine = {
        enable = true;
        enableEditor = false;
        maxGenerations = 10;

        style = {
          wallpapers = [wallpaper];
          wallpaperStyle = "stretched";

          interface = {
            resolution = "1920x1080";
            branding = "mugdad";
            brandingColor = gruvbox.fg;
            helpColor = gruvbox.gray;
            helpColorBright = gruvbox.bright_yellow;
          };

          graphicalTerminal = {
            foreground = gruvbox.fg;
            background = "FF${gruvbox.bg0_h}";
            brightForeground = gruvbox.fg0;
            brightBackground = gruvbox.bg0;
            palette = "${gruvbox.bg0_h};${gruvbox.red};${gruvbox.green};${gruvbox.yellow};${gruvbox.blue};${gruvbox.purple};${gruvbox.aqua};${gruvbox.gray}";
            brightPalette = "${gruvbox.dark_gray};${gruvbox.bright_red};${gruvbox.bright_green};${gruvbox.bright_yellow};${gruvbox.bright_blue};${gruvbox.bright_purple};${gruvbox.bright_aqua};${gruvbox.fg}";
            margin = 8;
            marginGradient = 4;
          };
        };
      };

      efi.canTouchEfiVariables = true;
    };

    kernelParams = lib.mkBefore [
      "quiet"
      "pcie_aspm=off"
      "nvidia.NVreg_DynamicPowerManagement=0x00000000"
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
