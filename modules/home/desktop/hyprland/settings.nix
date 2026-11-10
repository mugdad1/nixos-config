{variables, ...}: let
  c = (import ../../../../lib/gruvbox.nix).raw;
in ''
  ------------------
  ---- MONITORS ----
  ------------------

  -- Sway sets `output eDP-1 scale 1.2`; keep the same panel scale here.
  -- nwg-displays (Super+Shift+D) manages this file and overrides the default.
  hl.monitor({
      output   = "eDP-1",
      mode     = "preferred",
      position = "auto",
      scale    = 1.2,
  })

  pcall(dofile, os.getenv("HOME") .. "/.config/hypr/monitors.lua")

  -----------------------
  ---- LOOK AND FEEL ----
  -----------------------

  -- Deliberately flat: same gaps/borders/rounding and the same gruvbox
  -- borders as the sway config (modules/home/desktop/sway/sway.nix).
  -- No blur, no shadows, no animations.
  hl.config({
      general = {
          gaps_in      = 6,
          gaps_out     = 12,
          border_size  = 2,
          resize_on_border = true,
          layout       = "dwindle",

          col = {
              active_border   = "rgb(${c.bright_green})",
              inactive_border = "rgb(${c.gray})",
          },
      },

      decoration = {
          rounding = 0,
          blur = { enabled = false },
          shadow = { enabled = false },
      },

      animations = {
          enabled = false,
      },

      misc = {
          disable_hyprland_logo      = true,
          disable_splash_rendering   = true,
          initial_workspace_tracking = 0,
          focus_on_activate          = true,
          middle_click_paste         = false,
      },

      input = {
          kb_layout    = "${variables.keyboardLayout}",
          kb_options   = "${variables.keyboardOptions}",
          repeat_rate  = 50,
          repeat_delay = 300,
          follow_mouse = 1,
          sensitivity  = 0,

          touchpad = {
              tap_to_click         = true,
              tap_and_drag         = true,
              disable_while_typing = false,
              natural_scroll       = true,
          },
      },

      binds = {
          scroll_event_delay          = 100,
          movefocus_cycles_fullscreen = true,
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

  -- Three-finger swipe switches workspaces, like the old Hyprland setup.
  hl.gesture({ fingers = 3, direction = "horizontal", action = "workspace" })
''
