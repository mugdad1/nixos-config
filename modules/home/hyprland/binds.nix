{...}: let
  mod = "SUPER";
in ''
  ---------------------
  ---- KEYBINDINGS ----
  ---------------------

  local mod = "${mod}"

  -- App launchers
  hl.bind(mod .. " + RETURN",      hl.dsp.exec_cmd("ghostty --gtk-single-instance=true"))
  hl.bind("ALT + RETURN",          hl.dsp.exec_cmd("[float; size 1111 700] ghostty"))
  hl.bind(mod .. " + SHIFT + RETURN", hl.dsp.exec_cmd("[fullscreen] ghostty"))
  hl.bind(mod .. " + B",           hl.dsp.exec_cmd("zen-beta"))
  hl.bind(mod .. " + D",           hl.dsp.exec_cmd("toggle-rofi rofi -show drun"))
  hl.bind(mod .. " + E",           hl.dsp.exec_cmd("nemo"))
  hl.bind("ALT + E",               hl.dsp.exec_cmd("[float; size 1111 700] nemo"))
  hl.bind(mod .. " + W",           hl.dsp.exec_cmd("wallpaper-picker"))
  hl.bind(mod .. " + SHIFT + W",   hl.dsp.exec_cmd("[float; size 925 615] waypaper"))
  hl.bind(mod .. " + N",           hl.dsp.exec_cmd("swaync-client -t -sw"))
  hl.bind(mod .. " + C",           hl.dsp.exec_cmd("hyprpicker -a"))
  hl.bind(mod .. " + XF86Display", hl.dsp.exec_cmd("toggle-display"))

  hl.bind(mod .. " + S",           hl.dsp.exec_cmd("web-search"))

  -- Window management
  hl.bind(mod .. " + Q",           hl.dsp.window.close())
  hl.bind(mod .. " + F",           hl.dsp.window.fullscreen())
  hl.bind(mod .. " + SHIFT + F",   hl.dsp.window.fullscreen({ maximize = true }))
  hl.bind(mod .. " + Space",       hl.dsp.exec_cmd("toggle-float"))
  hl.bind(mod .. " + P",           hl.dsp.exec_cmd("power-profile-menu"))
  hl.bind(mod .. " + T",           hl.dsp.exec_cmd("toggle-opacity"))
  hl.bind(mod .. " + SHIFT + B",   hl.dsp.exec_cmd("toggle-waybar"))

  -- Lock and power
  hl.bind(mod .. " + Escape",          hl.dsp.exec_cmd("hyprlock"))
  hl.bind("ALT + Escape",              hl.dsp.exec_cmd("hyprlock & systemctl suspend"))
  hl.bind(mod .. " + SHIFT + Escape",  hl.dsp.exec_cmd("power-menu"))

  -- Screenshots
  hl.bind("Print",                    hl.dsp.exec_cmd("screenshot --copy"))
  hl.bind(mod .. " + Print",          hl.dsp.exec_cmd("screenshot --save"))
  hl.bind(mod .. " + SHIFT + Print",  hl.dsp.exec_cmd("screenshot --swappy"))

  -- OCR
  hl.bind(mod .. " + CTRL + O",       hl.dsp.exec_cmd("ocr"))

  -- Focus
  hl.bind(mod .. " + h",    hl.dsp.focus({ direction = "left" }))
  hl.bind(mod .. " + j",    hl.dsp.focus({ direction = "down" }))
  hl.bind(mod .. " + k",    hl.dsp.focus({ direction = "up" }))
  hl.bind(mod .. " + l",    hl.dsp.focus({ direction = "right" }))

  hl.bind(mod .. " + left",  hl.dsp.exec_cmd("hyprctl dispatch alterzorder top"))
  hl.bind(mod .. " + right", hl.dsp.exec_cmd("hyprctl dispatch alterzorder top"))
  hl.bind(mod .. " + up",    hl.dsp.exec_cmd("hyprctl dispatch alterzorder top"))
  hl.bind(mod .. " + down",  hl.dsp.exec_cmd("hyprctl dispatch alterzorder top"))

  hl.bind("CTRL + ALT + up",   hl.dsp.exec_cmd("hyprctl dispatch focuswindow floating"))
  hl.bind("CTRL + ALT + down", hl.dsp.exec_cmd("hyprctl dispatch focuswindow tiled"))

  -- Workspaces
  for i = 1, 10 do
      local key = i % 10
      hl.bind(mod .. " + " .. key,          hl.dsp.focus({ workspace = i }))
      hl.bind(mod .. " + SHIFT + " .. key,  hl.dsp.window.move({ workspace = i }))
  end
  hl.bind(mod .. " + CTRL + c", hl.dsp.exec_cmd("hyprctl dispatch movetoworkspace empty"))

  -- Window movement
  hl.bind(mod .. " + SHIFT + left",  hl.dsp.window.move({ direction = "left" }))
  hl.bind(mod .. " + SHIFT + right", hl.dsp.window.move({ direction = "right" }))
  hl.bind(mod .. " + SHIFT + up",    hl.dsp.window.move({ direction = "up" }))
  hl.bind(mod .. " + SHIFT + down",  hl.dsp.window.move({ direction = "down" }))
  hl.bind(mod .. " + SHIFT + h",     hl.dsp.window.move({ direction = "left" }))
  hl.bind(mod .. " + SHIFT + j",     hl.dsp.window.move({ direction = "down" }))
  hl.bind(mod .. " + SHIFT + k",     hl.dsp.window.move({ direction = "up" }))
  hl.bind(mod .. " + SHIFT + l",     hl.dsp.window.move({ direction = "right" }))

  -- Resize
  hl.bind(mod .. " + CTRL + left",  hl.dsp.window.resize({ x = -80, y = 0 }))
  hl.bind(mod .. " + CTRL + right", hl.dsp.window.resize({ x = 80, y = 0 }))
  hl.bind(mod .. " + CTRL + up",    hl.dsp.window.resize({ x = 0, y = -80 }))
  hl.bind(mod .. " + CTRL + down",  hl.dsp.window.resize({ x = 0, y = 80 }))
  hl.bind(mod .. " + CTRL + h",     hl.dsp.window.resize({ x = -80, y = 0 }))
  hl.bind(mod .. " + CTRL + j",     hl.dsp.window.resize({ x = 0, y = 80 }))
  hl.bind(mod .. " + CTRL + k",     hl.dsp.window.resize({ x = 0, y = -80 }))
  hl.bind(mod .. " + CTRL + l",     hl.dsp.window.resize({ x = 80, y = 0 }))

  -- Move active window
  hl.bind(mod .. " + ALT + left",  hl.dsp.window.move({ x = -80, y = 0, relative = true }))
  hl.bind(mod .. " + ALT + right", hl.dsp.window.move({ x = 80, y = 0, relative = true }))
  hl.bind(mod .. " + ALT + up",    hl.dsp.window.move({ x = 0, y = -80, relative = true }))
  hl.bind(mod .. " + ALT + down",  hl.dsp.window.move({ x = 0, y = 80, relative = true }))
  hl.bind(mod .. " + ALT + h",     hl.dsp.window.move({ x = -80, y = 0, relative = true }))
  hl.bind(mod .. " + ALT + j",     hl.dsp.window.move({ x = 0, y = 80, relative = true }))
  hl.bind(mod .. " + ALT + k",     hl.dsp.window.move({ x = 0, y = -80, relative = true }))
  hl.bind(mod .. " + ALT + l",     hl.dsp.window.move({ x = 80, y = 0, relative = true }))

  -- Media
  hl.bind("XF86AudioPlay", hl.dsp.exec_cmd("playerctl play-pause"), { locked = true })
  hl.bind("XF86AudioNext", hl.dsp.exec_cmd("playerctl next"),       { locked = true })
  hl.bind("XF86AudioPrev", hl.dsp.exec_cmd("playerctl previous"),   { locked = true })
  hl.bind("XF86AudioStop", hl.dsp.exec_cmd("playerctl stop"),       { locked = true })

  -- Mouse scroll
  hl.bind(mod .. " + mouse_down", hl.dsp.focus({ workspace = "e-1" }))
  hl.bind(mod .. " + mouse_up",   hl.dsp.focus({ workspace = "e+1" }))

  -- Clipboard
  hl.bind(mod .. " + V", hl.dsp.exec_cmd([[toggle-rofi "cliphist list | rofi -dmenu -theme-str 'window {width: 50%;} listview {columns: 1;}' | cliphist decode | wl-copy"]]))

  -- Mouse binds
  hl.bind(mod .. " + mouse:272", hl.dsp.window.drag(),   { mouse = true })
  hl.bind(mod .. " + mouse:273", hl.dsp.window.resize(), { mouse = true })

  -- Lid switch
  hl.bind("switch:on:Lid Switch", hl.dsp.exec_cmd("pidof hyprlock || hyprlock"), { locked = true })

  -- SwayOSD
  hl.bind("XF86AudioMute",        hl.dsp.exec_cmd("swayosd-client --output-volume mute-toggle"), { locked = true })
  hl.bind("XF86AudioMicMute",     hl.dsp.exec_cmd("toggle-mic"),                                  { locked = true })
  hl.bind(mod .. " + XF86MonBrightnessUp",   hl.dsp.exec_cmd("swayosd-client --brightness 100"), { locked = true })
  hl.bind(mod .. " + XF86MonBrightnessDown", hl.dsp.exec_cmd("swayosd-client --brightness 0"),   { locked = true })
  hl.bind("XF86MonBrightnessUp",   hl.dsp.exec_cmd("swayosd-client --brightness raise"), { locked = true, repeating = true })
  hl.bind("XF86MonBrightnessDown", hl.dsp.exec_cmd("swayosd-client --brightness lower"), { locked = true, repeating = true })
  hl.bind("XF86AudioRaiseVolume", hl.dsp.exec_cmd("swayosd-client --output-volume +2"), { locked = true, repeating = true })
  hl.bind("XF86AudioLowerVolume", hl.dsp.exec_cmd("swayosd-client --output-volume -2"), { locked = true, repeating = true })
  hl.bind(mod .. " + f11",          hl.dsp.exec_cmd("swayosd-client --output-volume +2"), { repeating = true })
  hl.bind(mod .. " + f12",          hl.dsp.exec_cmd("swayosd-client --output-volume -2"), { repeating = true })
  hl.bind("Caps_Lock",              hl.dsp.exec_cmd("swayosd-client --caps-lock"),        { release = true })
  hl.bind("Scroll_Lock",            hl.dsp.exec_cmd("swayosd-client --scroll-lock"),      { release = true })
  hl.bind("Num_Lock",               hl.dsp.exec_cmd("swayosd-client --num-lock"),         { release = true })

  -- ROG keyboard LED toggle
  hl.bind(mod .. " + SHIFT + K", hl.dsp.exec_cmd("rog-kb-toggle"))
''
