{ pkgs, lib, ... }:
let
  gruvbox-kvantum-theme = pkgs.gruvbox-kvantum.override { variant = "Gruvbox-Dark-Green"; };
in
{
  qt = {
    enable = true;
    platformTheme.name = "qtct";
    style.name = "kvantum";
  };

  home.packages = [ gruvbox-kvantum-theme ];

  xdg.configFile."Kvantum/kvantum.kvconfig".text = ''
    [General]
    theme=Gruvbox-Dark-Green
  '';

  # Symlink theme into Kvantum's theme directory so it's found
  home.file.".local/share/Kvantum/Gruvbox-Dark-Green".source =
    "${gruvbox-kvantum-theme}/share/Kvantum/Gruvbox-Dark-Green";

  qt.qt5ctSettings = {
    Appearance = {
      style = "kvantum";
      icon_theme = "Papirus-Dark";
      standard_dialogs = "xdgdesktopportal";
    };
    Fonts = {
      fixed = "\"Maple Mono,14\"";
      general = "\"Maple Mono,14\"";
    };
  };

  qt.qt6ctSettings = {
    Appearance = {
      style = "kvantum";
      icon_theme = "Papirus-Dark";
      standard_dialogs = "xdgdesktopportal";
    };
    Fonts = {
      fixed = "\"Maple Mono,14\"";
      general = "\"Maple Mono,14\"";
    };
  };
}
