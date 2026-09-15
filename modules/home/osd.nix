{
  pkgs,
  variables,
  ...
}: let
  t = import ../../lib/theme.nix variables;
  c = t.css;
  rgba = t.hexToRgba;
in {
  home.packages = with pkgs; [swayosd];

  xdg.configFile."swayosd/config.toml".text = ''
    [server]
    max_volume = 100
    show_percentage = true
  '';

  xdg.configFile."swayosd/style.css".text = ''
    window {
        padding: 0px 10px;
        border-radius: 25px;
        background: ${rgba t.raw.bg0 "0.99"};
    }

    #container {
        margin: 15px;
    }

    image, label {
        color: ${c.fg0};
    }

    progressbar:disabled,
    image:disabled {
        opacity: 0.95;
    }

    progressbar {
        min-height: 6px;
        border-radius: 999px;
        background: transparent;
        border: none;
    }
    trough {
        min-height: inherit;
        border-radius: inherit;
        border: none;
        background: ${rgba t.raw.bg3 "0.5"};
    }
    progress {
        min-height: inherit;
        border-radius: inherit;
        border: none;
        background: ${c.green};
    }
  '';
}
