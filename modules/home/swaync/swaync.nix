{
  pkgs,
  ...
}: let
  c = (import ../../gruvbox.nix).css;
in {
  home.packages = with pkgs; [swaynotificationcenter];

  xdg.configFile."swaync/style.css".text = with c;
    ''
      :root {
          --bg-primary: ${bg0_h};
          --bg-secondary: ${bg0};
          --bg-button: ${bg2};
          --bg-button-hover: ${bg3};
          --text-primary: ${fg};
          --text-disabled: ${dark_gray};
          --border-color: ${light_gray};
          --priority-low: ${fg};
          --priority-normal: ${bright_blue};
          --priority-critical: ${bright_red};
          --transition-standard: 0.15s ease-in-out;
      }
    ''
    + builtins.readFile ./style.css;
  xdg.configFile."swaync/config.json".source = ./config.json;
}
