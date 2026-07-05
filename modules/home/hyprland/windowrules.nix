{...}: ''
  --------------------------------
  ---- WINDOWS AND WORKSPACES ----
  --------------------------------

  hl.window_rule({
      name  = "float-imv",
      match = { class = "^imv$" },
      float = true,
  })

  hl.window_rule({
      name  = "float-zenity",
      match = { class = "^zenity$" },
      float = true,
      size  = { 850, 500 },
  })

  hl.window_rule({
      name  = "float-waypaper",
      match = { class = "^waypaper$" },
      float = true,
      pin   = true,
  })

  hl.window_rule({
      name  = "float-fileroller",
      match = { class = "^org.gnome.FileRoller$" },
      float = true,
  })

  hl.window_rule({
      name  = "float-pavucontrol",
      match = { class = "^org.pulseaudio.pavucontrol$" },
      float = true,
  })

  hl.window_rule({
      name  = "pin-rofi",
      match = { class = "^rofi$" },
      pin   = true,
  })

  hl.window_rule({
      name  = "volume-control",
      match = { title = "^Volume Control$" },
      size  = { 700, 450 },
      move  = "40 55%",
  })

  hl.window_rule({
      name  = "pin-pip",
      match = { title = "^Picture-in-Picture$" },
      pin   = true,
      float = true,
  })

  hl.window_rule({
      name  = "obs-workspace",
      match = { class = "^com.obsproject.Studio$" },
      workspace = 8,
  })

  hl.window_rule({
      name  = "dim-portal-gtk",
      match = { class = "^xdg-desktop-portal-gtk$" },
      dim_around = true,
  })

  hl.window_rule({
      name  = "no-rounding-xwayland",
      match = { xwayland = true },
      rounding = 0,
  })

  -- Smart gaps / No gaps when only
  hl.window_rule({
      name  = "no-gaps-wtv1",
      match = { float = false, workspace = "w[tv1]" },
      border_size = 0,
      rounding    = 0,
  })

  hl.window_rule({
      name  = "no-gaps-f1",
      match = { float = false, workspace = "f[1]" },
      border_size = 0,
      rounding    = 0,
  })

  -- Layer rules
  hl.layer_rule({
      name  = "dim-rofi",
      match = { namespace = "rofi" },
      dim_around = true,
  })

  hl.layer_rule({
      name  = "dim-swaync",
      match = { namespace = "swaync-control-center" },
      dim_around = true,
  })

  -- Workspace rules
  hl.workspace_rule({ workspace = "w[tv1]", gaps_out = 0, gaps_in = 0 })
  hl.workspace_rule({ workspace = "f[1]",   gaps_out = 0, gaps_in = 0 })
''
