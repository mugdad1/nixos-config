{ pkgs, lib, ... }:
{
  qt = {
    enable = true;
    platformTheme.name = "qtct";
    style.name = "kvantum";
  };

  home.packages = with pkgs; [
    (gruvbox-kvantum.override { variant = "Gruvbox-Dark-Brown"; })
  ];

  xdg.configFile."Kvantum/kvantum.kvconfig".text = ''
    [General]
    theme=Gruvbox-Dark-Brown
  '';

  # Symlink theme into Kvantum's theme directory so it's found
  home.file.".local/share/Kvantum/Gruvbox-Dark-Brown".source =
    "${pkgs.gruvbox-kvantum.override { variant = "Gruvbox-Dark-Brown"; }}/share/Kvantum/Gruvbox-Dark-Brown";

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
