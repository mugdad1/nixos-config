{
  pkgs,
  variables,
  ...
}: let
  g = import ../../../lib/gruvbox.nix;
  raw = g.raw;
  concatLines = builtins.concatStringsSep "\n";

  mod = "Super";
  t = variables.terminal;
  b = variables.browser;
  l = variables.launcher;

  riztile = pkgs.callPackage ../../../packages/riztile.nix {};

  # action -> inline TOML value
  # plain           -> "close"
  # { spawn = ... } -> {spawn = "cmd"}
  # { set_active_tag = n } -> {set_active_tag = 5}
  renderAction = action:
    if builtins.isString action
    then ''"${
        builtins.replaceStrings ["\""] ["\\\""] action
      }"''
    else let
      rendered = concatLines (map (k: let
        v = action.${k};
      in "${k} = ${
        if builtins.isString v
        then ''"${
            builtins.replaceStrings ["\""] ["\\\""] v
          }"''
        else toString v
      },") (builtins.attrNames action));
    in "{${rendered}}";

  # Keybindings mapped to riztile actions.
  # riztile has no directional focus/move/resize; use prev/next window + tag actions.
  binds = builtins.concatLists [
    # app launchers
    [
      {
        key = "${mod} Return";
        value = {spawn = "${t} --gtk-single-instance=true";};
      }
      {
        key = "Alt Return";
        value = {spawn = t;};
      }
      {
        key = "${mod} B";
        value = {spawn = b;};
      }
      {
        key = "${mod} D";
        value = {spawn = "toggle-rofi ${l} -show drun";};
      }
      {
        key = "${mod} E";
        value = {spawn = "nemo";};
      }
      {
        key = "${mod} W";
        value = {spawn = "wallpaper-picker";};
      }
      {
        key = "${mod} N";
        value = {spawn = "swaync-client -t -sw";};
      }
      {
        key = "${mod} S";
        value = {spawn = "web-search";};
      }
      {
        key = "${mod} Y";
        value = {spawn = "yt-audio";};
      }
    ]
    # window management
    [
      {
        key = "${mod} Q";
        value = "close";
      }
      {
        key = "${mod} F";
        value = "toggle_fullscreen";
      }
      {
        key = "${mod} Space";
        value = "toggle_float";
      }
      {
        key = "${mod} Shift B";
        value = {spawn = "toggle-waybar";};
      }
    ]
    # lock and power
    [
      {
        key = "${mod} Escape";
        value = {spawn = "swaylock";};
      }
      {
        key = "Alt Escape";
        value = {spawn = "swaylock & systemctl suspend";};
      }
      {
        key = "${mod} Shift Escape";
        value = {spawn = "power-menu";};
      }
    ]
    # screenshots
    [
      {
        key = "Print";
        value = {spawn = "screenshot --save";};
      }
      {
        key = "${mod} Print";
        value = {spawn = "screenshot --copy";};
      }
      {
        key = "${mod} Shift Print";
        value = {spawn = "screenshot --swappy";};
      }
    ]
    # focus (riztile only has prev/next — replace directional h,j,k,l)
    [
      {
        key = "${mod} k";
        value = "focus_prev_window";
      }
      {
        key = "${mod} j";
        value = "focus_next_window";
      }
    ]
    # media + clipboard
    [
      {
        key = "XF86AudioPlay";
        value = {spawn = "playerctl play-pause";};
      }
      {
        key = "XF86AudioNext";
        value = {spawn = "playerctl next";};
      }
      {
        key = "XF86AudioPrev";
        value = {spawn = "playerctl previous";};
      }
      {
        key = "XF86AudioStop";
        value = {spawn = "playerctl stop";};
      }
      {
        key = "XF86AudioMute";
        value = {spawn = "swayosd-client --output-volume mute-toggle";};
      }
      {
        key = "XF86AudioMicMute";
        value = {spawn = "toggle-mic";};
      }
      {
        key = "XF86MonBrightnessUp";
        value = {spawn = "swayosd-client --brightness raise";};
      }
      {
        key = "XF86MonBrightnessDown";
        value = {spawn = "swayosd-client --brightness lower";};
      }
      {
        key = "XF86AudioRaiseVolume";
        value = {spawn = "swayosd-client --output-volume +2";};
      }
      {
        key = "XF86AudioLowerVolume";
        value = {spawn = "swayosd-client --output-volume -2";};
      }
      {
        key = "${mod} V";
        value = {
          spawn = "toggle-rofi \"cliphist list | ${l} -dmenu -theme-str 'window {width: 50%;} listview {columns: 1;}' | cliphist decode | wl-copy\"";
        };
      }
    ]
    # workspaces: Super + 1-9,0 (=10)
    (map (n: let
        tag = n - (n / 10) * 10;
      in {
        key = "${mod} ${toString tag}";
        value = {set_active_tag = n;};
      })
      (builtins.genList (i: i + 1) 10))
    # move window to workspace
    (map (n: let
        tag = n - (n / 10) * 10;
      in {
        key = "${mod} Shift ${toString tag}";
        value = {move_to_tag = n;};
      })
      (builtins.genList (i: i + 1) 10))
    # cycle tags
    [
      {
        key = "${mod} Tab";
        value = "cycle_next_tag";
      }
      {
        key = "${mod} Shift Tab";
        value = "cycle_prev_tag";
      }
    ]
  ];

  pointerbindings = [
    {
      key = "${mod} BTN_LEFT";
      value = "move";
    }
    {
      key = "${mod} BTN_RIGHT";
      value = "resize";
    }
  ];

  autostart = [
    "dbus-update-activation-environment --all --systemd WAYLAND_DISPLAY XDG_CURRENT_DESKTOP"
    "systemctl --user import-environment WAYLAND_DISPLAY XDG_CURRENT_DESKTOP"
    "systemctl --user start nixos-fake-graphical-session.target"
    "nm-applet"
    "poweralertd"
    "wl-clip-persist --clipboard both"
    "wl-paste --watch cliphist store"
    variables.bar
    "swaync"
    "udiskie --automount --notify --smart-tray"
    "init-wallpaper"
    "swayosd-server"
    "safeeyes"
    "${pkgs.kdePackages.polkit-kde-agent-1}/libexec/polkit-kde-authentication-agent-1"
  ];
in {
  home.packages = with pkgs; [
    riztile
    river
    awww
    grimblast
    wlr-randr
    wl-clip-persist
    cliphist
    wofi
    swaylock
    grim
    glib
    wayland
  ];

  xdg.configFile."riztile/config.toml".text = ''
    # mugdad's riztile configuration (river window manager)
    # generated from modules/home/river
    # https://github.com/mugdad1/nixos-config

    [layout]
    outer_gap = 12
    inner_gap = 6
    border_width = 2
    border_color = 0x${raw.green}FF
    master_count = 1
    master_factor = 0.6

    [tags]
    count = 10

    [keybindings]
    ${concatLines (map (x: "\"${x.key}\" = ${renderAction x.value}") binds)}

    [pointerbindings]
    ${concatLines (map (x: "\"${x.key}\" = \"${x.value}\"") pointerbindings)}

    [input]
    "*" = { tap = true, tap_and_drag = true, natural_scroll = true }

    [autostart]
    commands = [
    ${concatLines (map (c: "  \"${c}\",") autostart)}
    ]
  '';
}
