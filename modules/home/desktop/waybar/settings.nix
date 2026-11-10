{variables, ...}: let
  configFor = import ./config.nix variables;
in {
  # Sway keeps the default ~/.config/waybar/config.
  programs.waybar.settings.mainBar = configFor "sway/workspaces";

  # Hyprland gets its own file because it needs hyprland/workspaces; the
  # session script starts waybar with `-c ~/.config/waybar/config-hypr`.
  xdg.configFile."waybar/config-hypr".text = builtins.toJSON (configFor "hyprland/workspaces");
}
