# sway configuration for the t480s session (replaces river + kwm/kwim).
#
# Writes ~/.config/sway/config. Everything kwm/kwim carried over:
# - output baseline eDP-1 scale 1.2 (ex-seeded kanshi/displays.nix)
# - keyboard us,ara + grp:alt_shift_toggle + 50/300 repeat
# - touchpad tap/drag/natural-scroll
# - kwm keybindings (Mod4), floating rules, gaps, gruvbox borders
# - kwm startup programs (kanshi/wdisplays dropped — sway owns outputs)
# The kwm top bar is gone; tags now show in waybar's sway/workspaces.
{
  pkgs,
  variables,
  ...
}: let
  g = (import ../../../lib/gruvbox.nix).raw;
  hex = c: "#${c}";

  mod = "\$mod";
  alt = "\$alt";
  t = variables.terminal;
  b = variables.browser;
  l = variables.launcher;

  concatLines = builtins.concatStringsSep "\n";

  # tag number (1-10) -> keysym (10 -> "0")
  wsNum = n: toString (n - (n / 10) * 10);

  appLaunchers = [
    "  bindsym ${mod}+Return exec ${t} --gtk-single-instance=true"
    "  bindsym ${alt}+Return exec ${t}"
    "  bindsym ${mod}+b exec ${b}"
    "  bindsym ${mod}+d exec toggle-rofi ${l} -show drun"
    "  bindsym ${mod}+e exec nemo"
    "  bindsym ${mod}+w exec wallpaper-picker"
    "  bindsym ${mod}+n exec swaync-client -t -sw"
    "  bindsym ${mod}+x exec web-search"
    "  bindsym ${mod}+y exec yt-audio"
  ];

  windowManagement = [
    "  bindsym ${mod}+q kill"
    "  bindsym ${mod}+f fullscreen toggle"
    "  bindsym ${mod}+space floating toggle"
    "  bindsym ${mod}+Shift+b exec toggle-waybar"
    "  bindsym ${mod}+Shift+r reload"
  ];

  focusSwap = [
    "  bindsym ${mod}+k focus up"
    "  bindsym ${mod}+j focus down"
    "  bindsym ${mod}+Shift+k move up"
    "  bindsym ${mod}+Shift+j move down"
    "  bindsym ${mod}+l resize grow width 10px"
    "  bindsym ${mod}+h resize shrink width 10px"
  ];

  lockPower = [
    "  bindsym ${mod}+Escape exec swaylock"
    "  bindsym ${alt}+Escape exec \"swaylock && systemctl suspend\""
    "  bindsym ${mod}+Shift+Escape exec power-menu"
    "  bindsym F7 exec toggle-screen"
  ];

  screenshots = [
    "  bindsym Print exec screenshot --save"
    "  bindsym ${mod}+Print exec screenshot --copy"
    "  bindsym ${mod}+Shift+Print exec screenshot --swappy"
  ];

  mediaClipboard = [
    "  bindsym XF86AudioPlay exec playerctl play-pause"
    "  bindsym XF86AudioNext exec playerctl next"
    "  bindsym XF86AudioPrev exec playerctl previous"
    "  bindsym XF86AudioStop exec playerctl stop"
    "  bindsym XF86AudioMute exec swayosd-client --output-volume mute-toggle"
    "  bindsym XF86AudioMicMute exec toggle-mic"
    "  bindsym XF86MonBrightnessUp exec swayosd-client --brightness +5"
    "  bindsym XF86MonBrightnessDown exec swayosd-client --brightness -5"
    "  bindsym XF86AudioRaiseVolume exec swayosd-client --output-volume +2"
    "  bindsym XF86AudioLowerVolume exec swayosd-client --output-volume -2"
    "  bindsym ${mod}+v exec toggle-rofi sh -c \"cliphist list | ${l} -dmenu -theme-str 'window {width: 50%;} listview {columns: 1;}' | cliphist decode | wl-copy\""
  ];

  workspaceGo =
    map (n: "  bindsym ${mod}+${wsNum n} workspace number ${toString n}")
    (builtins.genList (i: i + 1) 10);

  workspaceMove =
    map (n: "  bindsym ${mod}+Shift+${wsNum n} move container to workspace number ${toString n}")
    (builtins.genList (i: i + 1) 10);

  workspaceCycle = [
    "  bindsym ${mod}+Tab workspace next"
    "  bindsym ${mod}+Shift+Tab workspace prev"
  ];

  binds = builtins.concatLists [
    appLaunchers
    windowManagement
    focusSwap
    lockPower
    screenshots
    mediaClipboard
    workspaceGo
    workspaceMove
    workspaceCycle
  ];

  polkitAgent = "${pkgs.kdePackages.polkit-kde-agent-1}/libexec/polkit-kde-authentication-agent-1";

  startup = [
    ["dbus-update-activation-environment" "--systemd" "--all"]
    ["systemctl" "--user" "import-environment" "WAYLAND_DISPLAY" "XDG_CURRENT_DESKTOP"]
    ["systemctl" "--user" "start" "nixos-fake-graphical-session.target"]
    ["nm-applet"]
    ["poweralertd"]
    ["wl-clip-persist" "--clipboard" "both"]
    ["wl-paste" "--watch" "cliphist" "store"]
    ["waybar"]
    ["swaync"]
    ["udiskie" "--automount" "--notify" "--smart-tray"]
    ["init-wallpaper"]
    ["swayosd-server"]
    [polkitAgent]
  ];
  execLine = argv: "  exec ${builtins.concatStringsSep " " argv}";

  floatingRules = [
    "  for_window [app_id=\"zenity\"] floating enable"
    "  for_window [app_id=\"waypaper\"] floating enable"
    "  for_window [app_id=\"pavucontrol\"] floating enable"
    "  for_window [app_id=\"org.gnome.FileRoller\"] floating enable"
    "  for_window [app_id=\"imv\"] floating enable"
    "  for_window [app_id=\".*polkit.*\"] floating enable"
    "  for_window [app_id=\"xdg-desktop-portal-gtk\"] floating enable"
    "  for_window [app_id=\"DesktopEditors\"] floating enable"
  ];
in {
  home.packages = with pkgs; [
    sway
    awww
    slurp
    wlr-randr
    wl-clip-persist
    wlopm
    cliphist
    grim
    glib
    wayland
  ];

  xdg.configFile."sway/config".text = ''
    // mugdad's sway configuration (replaces river + kwm/kwim)
    // generated from modules/home/sway/sway.nix
    // https://github.com/mugdad1/nixos-config
    set $mod Mod4
    set $alt Mod1

    font pango:Iosevka Nerd Font 12

    // outputs — sway owns them directly (kanshi/wdisplays dropped)
    output eDP-1 scale 1.2

    gaps inner 6
    gaps outer 12

    default_border pixel 2
    default_orientation horizontal
    focus_follows_mouse yes
    focus_wrapping yes
    floating_modifier $mod normal

    // gruvbox borders (kwm carried over)
    client.focused          ${hex g.bright_green} ${hex g.bright_green} ${hex g.bg0} ${hex g.bright_green} ${hex g.bright_green}
    client.focused_inactive ${hex g.gray} ${hex g.gray} ${hex g.bg0} ${hex g.gray} ${hex g.gray}
    client.unfocused        ${hex g.gray} ${hex g.gray} ${hex g.bg0} ${hex g.gray} ${hex g.gray}

    input type:keyboard {
        xkb_layout ${variables.keyboardLayout}
        xkb_options ${variables.keyboardOptions}
        repeat_rate 50
        repeat_delay 300
    }

    input type:touchpad {
        tap enabled
        drag enabled
        natural_scroll enabled
    }

    // bindings
    ${concatLines binds}

    // floating window rules (kwm carried over)
    ${concatLines floatingRules}

    // startup (kwm carried over; kanshi gone — outputs are static in sway)
    ${concatLines (map execLine startup)}
  '';
}
