{
  pkgs,
  variables,
  ...
}: let
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
  xdg.configFile."rofi/config.rasi".text = ''
    configuration{
        modi: "run,drun,window";
        lines: 5;
        cycle: false;
        font: "Iosevka Nerd Font Bold 16";
        show-icons: true;
        icon-theme: "Papirus-dark";
        terminal: "${variables.terminal}";
        drun-display-format: "{icon} {name}";
        location: 0;
        disable-history: true;
        hide-scrollbar: true;
        display-drun: " Apps ";
        display-run: " Run ";
        display-window: " Window ";
        sidebar-mode: true;
        sorting-method: "fzf";
    }

    @theme "theme"

    element-text, element-icon , mode-switcher {
        background-color: inherit;
        text-color:       inherit;
    }

    window {
        height: 539px;
        width: 400px;
        border: 2px;
        border-color: @border-col;
        background-color: @bg-col;
    }

    mainbox {
        background-color: @bg-col;
    }

    inputbar {
        children: [prompt,entry];
        background-color: @bg-col-light;
        padding: 0px;
    }

    prompt {
        background-color: @green;
        padding: 4px;
        text-color: @bg-col-light;
        margin: 10px 0px 10px 10px;
    }

    textbox-prompt-colon {
        expand: false;
        str: ":";
    }

    entry {
        padding: 6px;
        margin: 10px 10px 10px 5px;
        text-color: @fg-col;
        background-color: @bg-col;
    }

    listview {
        border: 0px 0px 0px;
        padding: 0px;
        margin: 0px;
        columns: 1;
        background-color: @bg-col;
        cycle: true;
    }

    element {
        padding: 8px 8px 8px 8px;
        margin: 0px;
        background-color: @element-bg;
        text-color: @fg-col;
    }

    element-icon {
        size: 28px;
    }

    element selected {
        background-color:  @selected-col ;
        text-color: @fg-col2  ;
    }

    element alternate.normal {
        background-color: @element-alternate-bg;
        text-color:       @fg-col;
    }

    mode-switcher {
        spacing: 0;
    }

    button {
        padding: 10px;
        background-color: @bg-col-light;
        text-color: @grey;
        vertical-align: 0.5;
        horizontal-align: 0.5;
    }

    button selected {
        background-color: @bg-col;
        text-color: @green;
    }
  '';

  xdg.configFile."rofi/powermenu-theme.rasi".source = ./powermenu-theme.rasi;
}
