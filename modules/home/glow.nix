{...}: let
  c = (import ../../lib/gruvbox.nix).css;
in {
  # glow renders markdown in the terminal; point it at a gruvbox glamour style
  xdg.configFile."glow/glow.yml".text = ''
    style: "${./gruvbox-glamour.json}"
    mouse: true
    pager: true
    width: 100
  '';

  xdg.configFile."glow/gruvbox-glamour.json".text = builtins.toJSON {
    document = {
      style_block = {
        style_primitive = {
          color = c.fg;
          background_color = c.bg0;
        };
      };
    };
    block_quote = {
      style_block = {
        style_primitive = {color = c.gray;};
      };
      indent = 1;
      indent_token = "│ ";
    };
    paragraph = {};
    list = {
      level_indent = 2;
    };
    heading = {
      style_block = {
        style_primitive = {
          color = c.bright_green;
          background_color = c.bg0;
          bold = true;
        };
      };
    };
    h1 = {
      style_block = {
        style_primitive = {
          prefix = " ";
          suffix = " ";
          color = c.bg0_h;
          background_color = c.bright_red;
          bold = true;
        };
      };
    };
    h2 = {
      style_block = {
        style_primitive = {
          prefix = " ";
          suffix = " ";
          color = c.bg0_h;
          background_color = c.bright_orange;
          bold = true;
        };
      };
    };
    h3 = {
      style_block = {
        style_primitive = {
          prefix = " ";
          suffix = " ";
          color = c.bg0_h;
          background_color = c.bright_yellow;
          bold = true;
        };
      };
    };
    h4 = {
      style_block = {
        style_primitive = {
          prefix = " ";
          suffix = " ";
          color = c.bg0_h;
          background_color = c.bright_green;
          bold = true;
        };
      };
    };
    h5 = {
      style_block = {
        style_primitive = {
          prefix = " ";
          suffix = " ";
          color = c.bg0_h;
          background_color = c.bright_blue;
          bold = true;
        };
      };
    };
    h6 = {
      style_block = {
        style_primitive = {
          prefix = " ";
          suffix = " ";
          color = c.bg0_h;
          background_color = c.bright_purple;
          bold = true;
        };
      };
    };
    text = {
      style_block = {
        style_primitive = {color = c.fg;};
      };
    };
    strikethrough = {
      style_block = {
        style_primitive = {
          color = c.gray;
          cross_out = true;
        };
      };
    };
    emph = {
      style_block = {
        style_primitive = {
          color = c.fg;
          italic = true;
        };
      };
    };
    strong = {
      style_block = {
        style_primitive = {
          color = c.fg;
          bold = true;
        };
      };
    };
    hr = {
      style_block = {
        style_primitive = {color = c.bg3;};
      };
      format = "\n────────────────────────────────────────\n";
    };
    item = {
      style_block = {
        style_primitive = {color = c.fg;};
      };
    };
    enumeration = {
      style_block = {
        style_primitive = {color = c.fg;};
      };
    };
    task = {
      ticked = "[✓] ";
      unticked = "[ ] ";
      style_block = {
        style_primitive = {color = c.yellow;};
      };
    };
    link = {
      style_block = {
        style_primitive = {
          color = c.bright_blue;
          underline = true;
        };
      };
    };
    image = {
      style_block = {
        style_primitive = {
          color = c.bright_blue;
          underline = true;
        };
      };
    };
    code = {
      style_block = {
        style_primitive = {
          prefix = " ";
          suffix = " ";
          color = c.bright_aqua;
          background_color = c.bg1;
        };
      };
    };
    code_block = {
      style_block = {
        style_primitive = {
          color = c.fg;
          background_color = c.bg0_h;
        };
      };
      chroma = {
        text = {
          style_primitive = {color = c.fg;};
        };
        error = {
          style_primitive = {
            color = c.bright_red;
            background_color = c.bg0_h;
          };
        };
        comment = {
          style_primitive = {color = c.gray;};
        };
        comment_preproc = {
          style_primitive = {color = c.bright_purple;};
        };
        keyword = {
          style_primitive = {color = c.bright_red;};
        };
        keyword_reserved = {
          style_primitive = {color = c.bright_purple;};
        };
        keyword_namespace = {
          style_primitive = {color = c.bright_orange;};
        };
        keyword_type = {
          style_primitive = {color = c.bright_yellow;};
        };
        name = {
          style_primitive = {color = c.bright_blue;};
        };
        name_class = {
          style_primitive = {color = c.bright_yellow;};
        };
        name_function = {
          style_primitive = {
            color = c.bright_green;
            bold = true;
          };
        };
        name_other = {
          style_primitive = {color = c.fg;};
        };
        name_variable = {
          style_primitive = {color = c.bright_blue;};
        };
        number = {
          style_primitive = {color = c.bright_purple;};
        };
        operator = {
          style_primitive = {color = c.bright_orange;};
        };
        literal = {
          style_primitive = {color = c.bright_aqua;};
        };
        string = {
          style_primitive = {color = c.bright_green;};
        };
        string_escape = {
          style_primitive = {color = c.bright_orange;};
        };
        generic_deleted = {
          style_primitive = {color = c.bright_red;};
        };
        generic_inserted = {
          style_primitive = {
            color = c.bright_green;
            bold = true;
          };
        };
      };
    };
  };
}
