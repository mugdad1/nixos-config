{pkgs, ...}: let
  c = (import ../../lib/gruvbox.nix).css;
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
        border: 10px;
        background: alpha(${c.bg0}, 0.99);
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
        background: alpha(${c.bg3}, 0.5);
    }
    progress {
        min-height: inherit;
        border-radius: inherit;
        border: none;
        background: ${c.green};
    }
  '';
}
