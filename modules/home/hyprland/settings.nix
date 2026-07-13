{variables, ...}: let
  c = (import ../../gruvbox.nix).raw;
in ''
  -----------------------
  ---- LOOK AND FEEL ----
  -----------------------

  hl.config({
      general = {
          gaps_in  = 6,
          gaps_out = 12,
          border_size = 2,

          col = {
              active_border   = { colors = { "rgb(${c.green})", "rgb(${c.red})" }, angle = 45 },
              inactive_border = "rgb(${c.bg2})",
          },

          resize_on_border = true,
          layout = "dwindle",
      },

      decoration = {
          rounding = 0,

          blur = {
              enabled  = true,
              size     = 3,
              noise    = 0,
              passes   = 2,
              contrast = 1.4,
              brightness = 1,
              xray     = true,
          },

          shadow = {
              enabled      = true,
              range        = 20,
              render_power = 3,
              offset       = "0 2",
              color        = "rgba(00000055)",
          },
      },

      animations = {
          enabled = true,
      },

      misc = {
          disable_hyprland_logo       = true,
          disable_splash_rendering    = true,
          initial_workspace_tracking  = 0,
          focus_on_activate           = true,
          middle_click_paste          = false,
      },

      input = {
          kb_layout      = "${variables.keyboardLayout}",
          kb_options     = "${variables.keyboardOptions}",
          repeat_delay   = 300,
          numlock_by_default = true,
          follow_mouse   = 1,
          sensitivity    = 0,

          touchpad = {
              disable_while_typing = false,
              natural_scroll       = true,
          },
      },

      binds = {
          scroll_event_delay           = 100,
          movefocus_cycles_fullscreen  = true,
      },

      dwindle = {
          force_split           = 2,
          preserve_split        = true,
          use_active_for_splits = true,
      },

      master = {
          new_status = "master",
      },

      xwayland = {
          force_zero_scaling = true,
      },
  })

  hl.curve("fluent_decel", { type = "bezier", points = { {0, 0.2}, {0.4, 1} } })
  hl.curve("easeOutCirc",  { type = "bezier", points = { {0, 0.55}, {0.45, 1} } })
  hl.curve("easeOutCubic", { type = "bezier", points = { {0.33, 1}, {0.68, 1} } })
  hl.curve("fade_curve",   { type = "bezier", points = { {0, 0.55}, {0.45, 1} } })

  -- Windows
  hl.animation({ leaf = "windowsIn",   enabled = false, speed = 4, bezier = "easeOutCubic", style = "popin 20%" })
  hl.animation({ leaf = "windowsOut",  enabled = false, speed = 4, bezier = "fluent_decel", style = "popin 80%" })
  hl.animation({ leaf = "windowsMove", enabled = true,  speed = 2, bezier = "fluent_decel", style = "slide" })

  -- Fade
  hl.animation({ leaf = "fadeIn",      enabled = true,  speed = 3, bezier = "fade_curve" })
  hl.animation({ leaf = "fadeOut",     enabled = true,  speed = 3, bezier = "fade_curve" })
  hl.animation({ leaf = "fadeSwitch",  enabled = false, speed = 1, bezier = "easeOutCirc" })
  hl.animation({ leaf = "fadeShadow",  enabled = true,  speed = 10, bezier = "easeOutCirc" })
  hl.animation({ leaf = "fadeDim",     enabled = true,  speed = 4, bezier = "fluent_decel" })
  hl.animation({ leaf = "workspaces",  enabled = true,  speed = 4, bezier = "easeOutCubic", style = "fade" })

  -- Gestures
  hl.gesture({ fingers = 3, direction = "horizontal", action = "workspace" })
''
