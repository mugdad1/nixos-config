# kwm configuration for the river session.
#
# Generates ~/.config/kwm/config.zon. kwm reads this file at runtime and
# merges it over its baked-in defaults (per-field; slices replace whole),
# so bindings/pointer/rules/bar/startup are all fully specified here.
# Bar lives on top (tags/mode/layout/title); waybar stays on bottom.
{
  pkgs,
  variables,
  ...
}: let
  g = import ../../../lib/gruvbox.nix;
  raw = g.raw;
  concatLines = builtins.concatStringsSep "\n";

  mod = "mod4";
  alt = "mod1";
  t = variables.terminal;
  b = variables.browser;
  l = variables.launcher;

  # 2^n (nix has no bit-shift builtin)
  pow2 = n:
    if n == 0
    then 1
    else 2 * pow2 (n - 1);
  # tag number (1-10) -> bitmask
  tagMask = n: toString (pow2 (n - 1));

  # modifiers attrset -> zon struct, e.g. { mod4 = true; } -> .{ .mod4 = true }
  renderMods = mods: let
    on = builtins.attrNames (pkgs.lib.filterAttrs (_: v: v) mods);
  in
    if on == []
    then ".{ }"
    else ".{ ${concatLines (map (k: ".${k} = true,") on)} }";

  # Keybinding entry. action is a zon fragment for the pressed action.
  # repeat=true uses .repeat (for held keys like mfact adjust).
  keyBind = {
    keysym,
    mods ? {},
    action,
    mode ? null,
    repeat ? false,
  }: let
    modePrefix =
      if mode == null
      then ""
      else ".mode = \"${mode}\", ";
    event =
      if repeat
      then ".event = .{ .repeat = ${action} },"
      else ".event = .{ .click = .{ .pressed = ${action} } },";
  in ".{ ${modePrefix}.keysym = \"${keysym}\", .modifiers = ${renderMods mods}, ${event} },";

  # spawn actions
  spawn = argv: ''.{ .spawn = .{ .argv = .{ ${concatLines (map (a: "\"${a}\",") argv)} } } }'';
  spawnShell = cmd: ''.{ .spawn_shell = .{ .cmd = "${cmd}" } }'';

  # tag actions
  setOutTag = mask: ''.{ .set_output_tag = .{ .tag = .{ .tag = ${mask} } } }'';
  setWinTag = mask: ''.{ .set_window_tag = .{ .tag = .{ .tag = ${mask} } } }'';

  binds = builtins.concatLists [
    # app launchers
    [
      (keyBind {
        keysym = "Return";
        mods.${mod} = true;
        action = spawn [t "--gtk-single-instance=true"];
      })
      (keyBind {
        keysym = "Return";
        mods.${alt} = true;
        action = spawn [t];
      })
      (keyBind {
        keysym = "b";
        mods.${mod} = true;
        action = spawn [b];
      })
      (keyBind {
        keysym = "d";
        mods.${mod} = true;
        action = spawnShell "toggle-rofi ${l} -show drun";
      })
      (keyBind {
        keysym = "e";
        mods.${mod} = true;
        action = spawn ["nemo"];
      })
      (keyBind {
        keysym = "w";
        mods.${mod} = true;
        action = spawn ["wallpaper-picker"];
      })
      (keyBind {
        keysym = "n";
        mods.${mod} = true;
        action = spawn ["swaync-client" "-t" "-sw"];
      })
      (keyBind {
        keysym = "x";
        mods.${mod} = true;
        action = spawn ["web-search"];
      })
      (keyBind {
        keysym = "y";
        mods.${mod} = true;
        action = spawn ["yt-audio"];
      })
    ]
    # window management
    [
      (keyBind {
        keysym = "q";
        mods.${mod} = true;
        action = ".close";
      })
      (keyBind {
        keysym = "f";
        mods.${mod} = true;
        action = ".{ .toggle_fullscreen = .{ .in_window = false } }";
      })
      # user muscle memory: Super Space toggles float (not layout cycle)
      (keyBind {
        keysym = "space";
        mods.${mod} = true;
        action = ".toggle_floating";
      })
      (keyBind {
        keysym = "b";
        mods.${mod} = true;
        mods.shift = true;
        action = spawn ["toggle-waybar"];
      })
      (keyBind {
        keysym = "r";
        mods.${mod} = true;
        mods.shift = true;
        action = ".reload_config";
      })
    ]
    # focus / swap (dwm-style iteration; hover focus via sloppy_focus)
    [
      (keyBind {
        keysym = "k";
        mods.${mod} = true;
        action = ".{ .focus_iter = .{ .direction = .reverse } }";
      })
      (keyBind {
        keysym = "j";
        mods.${mod} = true;
        action = ".{ .focus_iter = .{ .direction = .forward } }";
      })
      (keyBind {
        keysym = "k";
        mods.${mod} = true;
        mods.shift = true;
        action = ".{ .swap = .{ .direction = .reverse } }";
      })
      (keyBind {
        keysym = "j";
        mods.${mod} = true;
        mods.shift = true;
        action = ".{ .swap = .{ .direction = .forward } }";
      })
      # master factor adjust
      (keyBind {
        keysym = "l";
        mods.${mod} = true;
        action = ".{ .modify_mfact = .{ .change = .{ .step = 0.01 } } }";
        repeat = true;
      })
      (keyBind {
        keysym = "h";
        mods.${mod} = true;
        action = ".{ .modify_mfact = .{ .change = .{ .step = -0.01 } } }";
        repeat = true;
      })
    ]
    # lock and power
    [
      (keyBind {
        keysym = "Escape";
        mods.${mod} = true;
        action = spawn ["swaylock"];
      })
      (keyBind {
        keysym = "Escape";
        mods.${alt} = true;
        action = spawnShell "swaylock & systemctl suspend";
      })
      (keyBind {
        keysym = "Escape";
        mods.${mod} = true;
        mods.shift = true;
        action = spawn ["power-menu"];
      })
      (keyBind {
        keysym = "F7";
        action = spawn ["toggle-screen"];
      })
    ]
    # screenshots
    [
      (keyBind {
        keysym = "Print";
        action = spawn ["screenshot" "--save"];
      })
      (keyBind {
        keysym = "Print";
        mods.${mod} = true;
        action = spawn ["screenshot" "--copy"];
      })
      (keyBind {
        keysym = "Print";
        mods.${mod} = true;
        mods.shift = true;
        action = spawn ["screenshot" "--swappy"];
      })
    ]
    # media + clipboard (no-modifier keys)
    [
      (keyBind {
        keysym = "XF86AudioPlay";
        action = spawn ["playerctl" "play-pause"];
      })
      (keyBind {
        keysym = "XF86AudioNext";
        action = spawn ["playerctl" "next"];
      })
      (keyBind {
        keysym = "XF86AudioPrev";
        action = spawn ["playerctl" "previous"];
      })
      (keyBind {
        keysym = "XF86AudioStop";
        action = spawn ["playerctl" "stop"];
      })
      (keyBind {
        keysym = "XF86AudioMute";
        action = spawn ["swayosd-client" "--output-volume" "mute-toggle"];
      })
      (keyBind {
        keysym = "XF86AudioMicMute";
        action = spawn ["toggle-mic"];
      })
      (keyBind {
        keysym = "XF86MonBrightnessUp";
        action = spawn ["swayosd-client" "--brightness" "+5"];
        repeat = true;
      })
      (keyBind {
        keysym = "XF86MonBrightnessDown";
        action = spawn ["swayosd-client" "--brightness" "-5"];
        repeat = true;
      })
      (keyBind {
        keysym = "XF86AudioRaiseVolume";
        action = spawn ["swayosd-client" "--output-volume" "+2"];
        repeat = true;
      })
      (keyBind {
        keysym = "XF86AudioLowerVolume";
        action = spawn ["swayosd-client" "--output-volume" "-2"];
        repeat = true;
      })
      (keyBind {
        keysym = "v";
        mods.${mod} = true;
        action = spawnShell "toggle-rofi sh -c \\\"cliphist list | ${l} -dmenu -theme-str 'window {width: 50%;} listview {columns: 1;}' | cliphist decode | wl-copy\\\"";
      })
    ]
    # workspaces: Super + 1-9,0 (=10)
    (map (n: let
        tag = n - (n / 10) * 10;
      in (keyBind {
        keysym = toString tag;
        mods.${mod} = true;
        action = setOutTag (tagMask n);
      }))
      (builtins.genList (i: i + 1) 10))
    # move window to workspace
    (map (n: let
        tag = n - (n / 10) * 10;
      in (keyBind {
        keysym = toString tag;
        mods.${mod} = true;
        mods.shift = true;
        action = setWinTag (tagMask n);
      }))
      (builtins.genList (i: i + 1) 10))
    # cycle tags
    [
      (keyBind {
        keysym = "Tab";
        mods.${mod} = true;
        action = ".{ .set_output_tag = .{ .tag = .{ .direction = .forward } } }";
      })
      (keyBind {
        keysym = "Tab";
        mods.${mod} = true;
        mods.shift = true;
        action = ".{ .set_output_tag = .{ .tag = .{ .direction = .reverse } } }";
      })
    ]
  ];

  pointerbindings = [
    ".{ .mode = \"default\", .button = .left, .modifiers = .{ .${mod} = true }, .event = .{ .pressed = .pointer_move } },"
    ".{ .mode = \"default\", .button = .right, .modifiers = .{ .${mod} = true }, .event = .{ .pressed = .pointer_resize } },"
  ];

  # startup programs (argv arrays; kwm execs directly, no shell)
  startup = [
    ["dbus-update-activation-environment" "--systemd" "--all"]
    ["systemctl" "--user" "import-environment" "WAYLAND_DISPLAY" "XDG_CURRENT_DESKTOP"]
    ["systemctl" "--user" "start" "nixos-fake-graphical-session.target"]
    ["nm-applet"]
    ["poweralertd"]
    ["wl-clip-persist" "--clipboard" "both"]
    ["wl-paste" "--watch" "cliphist" "store"]
    [variables.bar]
    ["swaync"]
    ["kanshi"]
    ["udiskie" "--automount" "--notify" "--smart-tray"]
    ["init-wallpaper"]
    ["swayosd-server"]
    ["safeeyes"]
    ["${pkgs.kdePackages.polkit-kde-agent-1}/libexec/polkit-kde-authentication-agent-1"]
  ];

  windowRules = [
    ".{ .app_id = .{ .str = \"\", .match_null = true }, .floating = true },"
    ".{ .app_id = .{ .str = \"zenity\" }, .floating = true },"
    ".{ .app_id = .{ .str = \"waypaper\" }, .floating = true },"
    ".{ .app_id = .{ .str = \"pavucontrol\" }, .floating = true },"
    ".{ .app_id = .{ .str = \"org.gnome.FileRoller\" }, .floating = true },"
    ".{ .app_id = .{ .str = \"imv\" }, .floating = true },"
    ".{ .app_id = .{ .str = \".*polkit.*\", .regex = true }, .floating = true },"
    ".{ .app_id = .{ .str = \"xdg-desktop-portal-gtk\" }, .floating = true },"
    ".{ .app_id = .{ .str = \"DesktopEditors\" }, .floating = true },"
    ".{ .app_id = .{ .str = \"${t}\" }, .is_terminal = true },"
  ];

  barTags = builtins.genList (i: ''"${toString (i + 1 - ((i + 1) / 10) * 10)}",'') 10;
in {
  xdg.configFile."kwm/config.zon".text = ''
    // mugdad's kwm configuration (river window manager)
    // generated from modules/home/river/kwm.nix
    // https://github.com/mugdad1/nixos-config
    .{
        .sloppy_focus = true,

        // null: awww sets the wallpaper, a solid color would cover it
        .background = null,

        .border = .{
            .width = 2,
            .color = .{
                .focus = 0x${raw.bright_green}ff,
                .unfocus = 0x${raw.gray}ff,
                .swallowing = 0x${raw.bright_green}ff,
            },
        },

        .default_layout = .tile,
        .layout = .{
            .tile = .{
                .nmaster = 1,
                .mfact = 0.6,
                .inner_gap = 6,
                .outer_gap = 12,
                .master_location = .left,
            },
        },

        .remember_floating_geometry = true,

        .bar = .{
            .show_default = true,
            .position = .top,
            .font = "monospace:size=12",
            .scheme = .{
                .normal = .{
                    .fg = 0x${raw.fg}ff,
                    .bg = 0x${raw.bg0}ff,
                },
                .select = .{
                    .fg = 0x${raw.bg0}ff,
                    .bg = 0x${raw.bright_green}ff,
                },
            },
            .tags = .{
                .tags = .{
                    ${concatLines barTags}
                },
                .click = .{
                    .left = .{ .set_output_tag = .{ .tag = .{ .tag = 0 } } },
                    .right = .{ .toggle_output_tag = .{ .mask = 0 } },
                    .middle = .{ .toggle_window_tag = .{ .mask = 0 } },
                },
            },
            .mode = .{
                .tags = .{
                    .{ "default", "" },
                    .{ "passthrough", "P" },
                    .{ "floating", "F" },
                },
                .click = .{
                    .left = .{ .switch_mode = .{ .mode = "default" } },
                },
            },
            .layout = .{
                .tags = .{
                    .tile = .{
                        .left = "[]=",
                        .right = "=[]",
                        .top = "[^]",
                        .bottom = "[_]",
                    },
                    .grid = .{
                        .horizontal = "|+|",
                        .vertical = "|||",
                    },
                    .monocle = "[{{=}}]",
                    .deck = .{
                        .left = "[{{D}}]=",
                        .right = "=[{{D}}]",
                        .top = "[{{D}}^]",
                        .bottom = "[{{D}}_]",
                    },
                    .scroller = "[==]",
                    .centered_master = .{
                        .horizontal = "=[]=",
                        .vertical = "=[V]="
                    },
                    .float = "><>",
                },
                .click = .{
                    .left = .switch_to_previous_layout,
                },
            },
            .title = .{
                .click = .{
                    .left = .{ .zoom = .{ .swap = false } },
                },
            },
            // waybar (bottom) covers clock/battery/tray — no status here
            .status = null,
            .override_colors = .{
            },
        },

        .single_tagset = false,

        .bindings = .{
            .key = .{
                ${concatLines binds}
            },
            .pointer = .{
                ${concatLines pointerbindings}
            },
        },

        .window_rules = .{
            ${concatLines windowRules}
        },

        .startup_cmds = .{
            ${concatLines (map (argv: ''.{ ${concatLines (map (a: "\"${a}\",") argv)} },'') startup)}
        },
    }
  '';
}
