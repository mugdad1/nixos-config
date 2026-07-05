{pkgs, ...}: let
  c = (import ../../gruvbox.nix).css;
in {
  home.packages = with pkgs; [rofi];

  xdg.configFile."rofi/theme.rasi".text = ''
    * {
        bg-col: ${c.bg0_h};
        bg-col-light: ${c.bg0};
        border-col: ${c.gray};
        selected-col: ${c.bg1};
        green: ${c.green};
        fg-col: ${c.fg0};
        fg-col2: ${c.fg};
        grey: ${c.light_gray};
        element-bg: ${c.bg0};
        element-alternate-bg: ${c.bg1};
    }
  '';
  xdg.configFile."rofi/config.rasi".source = ./config.rasi;

  xdg.configFile."rofi/powermenu-theme.rasi".source = ./powermenu-theme.rasi;
}
