{
  pkgs,
  variables,
  ...
}: let
  compositor = variables.compositor or "hyprland";
in {
  programs.hyprland = {
    enable = compositor == "hyprland";
  };

  xdg.portal = {
    enable = true;
    xdgOpenUsePortal = true;
    config =
      {
        common.default = ["gtk"];
      }
      // (
        if compositor == "hyprland"
        then {
          hyprland.default = [
            "gtk"
            "hyprland"
          ];
        }
        else {}
      );

    extraPortals =
      [
        pkgs.xdg-desktop-portal-gtk
      ]
      ++ (
        if compositor == "hyprland"
        then [
          pkgs.xdg-desktop-portal-hyprland
        ]
        else []
      );
  };
}
