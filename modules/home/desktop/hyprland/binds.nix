{variables, ...}: let
  t = variables.terminal;
  b = variables.browser;
  l = variables.launcher;
in ''
  ---------------------
  ---- KEYBINDINGS ----
  ---------------------

  local mod = "SUPER"

  -- App launchers (same list as sway)
  hl.bind(mod .. " + Return",       hl.dsp.exec_cmd("${t}"))
  hl.bind("ALT + Return",           hl.dsp.exec_cmd("${t}"))
  hl.bind(mod .. " + B",            hl.dsp.exec_cmd("${b}"))
  hl.bind(mod .. " + D",            hl.dsp.exec_cmd("toggle-rofi ${l} -show drun"))
  hl.bind(mod .. " + SHIFT + D",    hl.dsp.exec_cmd("nwg-displays"))
  hl.bind(mod .. " + E",            hl.dsp.exec_cmd("nemo"))
  hl.bind(mod .. " + W",            hl.dsp.exec_cmd("wallpaper-picker"))
  hl.bind(mod .. " + N",            hl.dsp.exec_cmd("swaync-client -t -sw"))
  hl.bind(mod .. " + X",            hl.dsp.exec_cmd("web-search"))
  hl.bind(mod .. " + Y",            hl.dsp.exec_cmd("yt-audio"))

  -- Window management
  hl.bind(mod .. " + Q",            hl.dsp.window.close())
  hl.bind(mod .. " + F",            hl.dsp.window.fullscreen())
  hl.bind(mod .. " + space",        hl.dsp.window.float({ action = "toggle" }))
  hl.bind(mod .. " + SHIFT + B",    hl.dsp.exec_cmd("toggle-waybar"))
  hl.bind(mod .. " + SHIFT + R",    hl.dsp.reload_config())

  -- Focus / move / resize (same keys as sway)
  hl.bind(mod .. " + K",            hl.dsp.focus({ direction = "up" }))
  hl.bind(mod .. " + J",            hl.dsp.focus({ direction = "down" }))
  hl.bind(mod .. " + SHIFT + K",    hl.dsp.window.move({ direction = "up" }))
  hl.bind(mod .. " + SHIFT + J",    hl.dsp.window.move({ direction = "down" }))
  hl.bind(mod .. " + L",            hl.dsp.window.resize({ x = 10, y = 0, relative = true }))
  hl.bind(mod .. " + H",            hl.dsp.window.resize({ x = -10, y = 0, relative = true }))

  -- Lock and power
  hl.bind(mod .. " + Escape",         hl.dsp.exec_cmd("hyprlock"))
  hl.bind("ALT + Escape",             hl.dsp.exec_cmd("hyprlock && systemctl suspend"))
  hl.bind(mod .. " + SHIFT + Escape", hl.dsp.exec_cmd("power-menu"))
  hl.bind(mod .. " + F7",             hl.dsp.exec_cmd("toggle-screen"))

  -- Screenshots
  hl.bind("Print",                   hl.dsp.exec_cmd("screenshot --save"))
  hl.bind(mod .. " + Print",         hl.dsp.exec_cmd("screenshot --copy"))
  hl.bind(mod .. " + SHIFT + Print", hl.dsp.exec_cmd("screenshot --swappy"))

  -- Media and clipboard
  hl.bind("XF86AudioPlay",        hl.dsp.exec_cmd("playerctl play-pause"), { locked = true })
  hl.bind("XF86AudioNext",        hl.dsp.exec_cmd("playerctl next"),       { locked = true })
  hl.bind("XF86AudioPrev",        hl.dsp.exec_cmd("playerctl previous"),   { locked = true })
  hl.bind("XF86AudioStop",        hl.dsp.exec_cmd("playerctl stop"),       { locked = true })
  hl.bind("XF86AudioMute",        hl.dsp.exec_cmd("swayosd-client --output-volume mute-toggle"), { locked = true })
  hl.bind("XF86AudioMicMute",     hl.dsp.exec_cmd("toggle-mic"),           { locked = true })
  hl.bind("XF86MonBrightnessUp",  hl.dsp.exec_cmd("swayosd-client --brightness +5"),    { locked = true, repeating = true })
  hl.bind("XF86MonBrightnessDown",hl.dsp.exec_cmd("swayosd-client --brightness -5"),    { locked = true, repeating = true })
  hl.bind("XF86AudioRaiseVolume", hl.dsp.exec_cmd("swayosd-client --output-volume +2"), { locked = true, repeating = true })
  hl.bind("XF86AudioLowerVolume", hl.dsp.exec_cmd("swayosd-client --output-volume -2"), { locked = true, repeating = true })

  hl.bind(mod .. " + V", hl.dsp.exec_cmd([[toggle-rofi sh -c "cliphist list | ${l} -dmenu -theme-str 'window {width: 50%;} listview {columns: 1;}' | cliphist decode | wl-copy"]]))

  -- Workspaces
  for i = 1, 10 do
      local key = i % 10
      hl.bind(mod .. " + " .. key,         hl.dsp.focus({ workspace = i }))
      hl.bind(mod .. " + SHIFT + " .. key, hl.dsp.window.move({ workspace = i }))
  end

  hl.bind(mod .. " + Tab",       hl.dsp.focus({ workspace = "m+1" }))
  hl.bind(mod .. " + SHIFT + Tab", hl.dsp.focus({ workspace = "m-1" }))

  -- Mouse: mod+drag moves, mod+right-drag resizes (sway floating_modifier)
  hl.bind(mod .. " + mouse:272", hl.dsp.window.drag(),   { mouse = true })
  hl.bind(mod .. " + mouse:273", hl.dsp.window.resize(), { mouse = true })
''
