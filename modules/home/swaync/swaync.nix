{lib, ...}: let
  c = (import ../../../lib/gruvbox.nix).css;
in {
  services.swaync = {
    enable = true;
    settings = {
      "ignore-gtk-theme" = true;
      positionX = "right";
      positionY = "top";
      layer = "overlay";
      "control-center-layer" = "top";
      "layer-shell" = true;
      "layer-shell-cover-screen" = true;
      cssPriority = "user";
      "control-center-margin-top" = 15;
      "control-center-margin-bottom" = 15;
      "control-center-margin-right" = 15;
      "control-center-margin-left" = 0;
      "notification-2fa-action" = true;
      "notification-inline-replies" = false;
      "notification-body-image-height" = 100;
      "notification-body-image-width" = 200;
      "notification-icon-size" = 48;
      timeout = 8;
      "timeout-low" = 6;
      "timeout-critical" = 0;
      "fit-to-screen" = true;
      "relative-timestamps" = true;
      "control-center-width" = 400;
      "control-center-height" = 600;
      "notification-window-width" = 350;
      "keyboard-shortcuts" = true;
      "notification-grouping" = true;
      "image-visibility" = "when-available";
      "transition-time" = 200;
      "hide-on-clear" = false;
      "hide-on-action" = true;
      "text-empty" = "No Notifications";
      "script-fail-notify" = true;
      widgets = ["title" "dnd" "mpris" "notifications" "volume" "backlight"];
      "widget-config" = {
        title = {
          text = "Notification Center";
          "clear-all-button" = true;
          "button-text" = "󰆴 Clear All";
        };
        dnd.text = "Do Not Disturb";
        mpris.show-album-art = "always";
        mpris.loop-carousel = false;
        volume.label = "󰕾 ";
        volume.expand-button-label = "";
        volume.collapse-button-label = "";
        volume.show-per-app = true;
        volume.show-per-app-icon = true;
        volume.show-per-app-label = false;
        backlight.label = "󰃟 ";
      };
    };
    style = with c;
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
  };
}
