_: let
  c = (import ../../../lib/gruvbox.nix).raw;
in {
  programs.ghostty = {
    enable = true;
    enableFishIntegration = true;

    settings = {
      ##### Font #####
      font-family = [
        "Iosevka Nerd Font"
      ];
      font-size = 12;
      font-feature = [
        "calt"
        "cv66"
        "ss05"
      ];

      ##### Theme #####
      theme = "gruvbox";
      background-opacity = 0.5;
      adjust-cursor-thickness = 1;

      selection-clear-on-copy = true;
      mouse-hide-while-typing = true;

      ##### Window #####
      window-padding-balance = true;
      window-padding-x = 4;
      window-padding-y = 4;
      window-padding-color = "background";
      window-decoration = "none";
      window-theme = "ghostty";
      window-inherit-working-directory = false;

      resize-overlay = "never";
      confirm-close-surface = false;
      app-notifications = "no-clipboard-copy";

      bell-features = "no-attention,no-audio,no-system,no-title,no-border";

      gtk-single-instance = false;
      gtk-tabs-location = "bottom";
      gtk-wide-tabs = false;
      gtk-custom-css = "styles/tabs.css";

      auto-update = "off";

      # Paste without a confirmation prompt, 2026-10-13. ghostty shipped
      # clipboard-read = "ask" + paste-protection = true, which means every
      # Ctrl+Shift+V pops a dialog to confirm before anything lands in the
      # shell — and with clipboard-read = "ask" a paste that the dialog does not
      # catch up with looks exactly like "pasting doesn't work", which is what
      # it was reported as. He pastes constantly (keys, tokens, commands off the
      # phone), so the prompt is pure friction here.
      #
      # The protection exists to stop a remote pane from scripting a paste of
      # something malicious. It is switched off on his machine on purpose — it
      # is his own clipboard, and the thing it guards against is a hostile
      # program on a box he already controls.
      clipboard-read = "allow";
      clipboard-write = "allow";
      clipboard-paste-protection = false;
    };

    themes.gruvbox = {
      background = c.bg0_h;
      foreground = c.fg0;

      cursor-color = c.fg2;

      selection-background = "cell-foreground";
      selection-foreground = "cell-background";

      palette = [
        "0=${c.bg0}"
        "1=${c.red}"
        "2=${c.green}"
        "3=${c.yellow}"
        "4=${c.blue}"
        "5=${c.purple}"
        "6=${c.aqua}"
        "7=${c.fg}"

        "8=${c.light_gray}"
        "9=${c.bright_red}"
        "10=${c.bright_green}"
        "11=${c.bright_yellow}"
        "12=${c.bright_blue}"
        "13=${c.bright_purple}"
        "14=${c.bright_aqua}"
        "15=${c.fg0}"
      ];
    };
  };

  xdg.configFile."ghostty/styles/tabs.css".text = let
    c = (import ../../../lib/gruvbox.nix).css;
  in ''
    headerbar {
        min-height: 30px;
        padding: 0;
        margin: 0;
    }

    tabbar tabbox {
        margin: 0;
        padding: 0;
        min-height: 30px;
        background-color: ${c.bg0_h};
    }

    tabbar tabbox tab {
        margin: 0;
        padding: 0;
        color: ${c.fg0};
    }

    tabbar tabbox tab:selected {
        background-color: ${c.bg0};
        color: ${c.fg0};
    }

    tabbar tabbox tab label {
        font-size: 18px;
    }
  '';
}
