{variables, ...}: let
  custom = import ./theme.nix;
  compositor = variables.compositor or "hyprland";
  # Hyprland exposes workspaces, river exposes tags
  workspaceModule =
    if compositor == "river"
    then "river/tags"
    else "hyprland/workspaces";
  # hyprctl can place the terminal floating+centered; river cannot
  btop =
    if compositor == "river"
    then "${variables.terminal} -e btop"
    else "hyprctl dispatch exec '[float; center; size 950 650] ${variables.terminal} -e btop'";
in {
  programs.waybar.settings.mainBar = with custom; {
    position = "bottom";
    layer = "top";
    height = 28;
    margin-top = 0;
    margin-bottom = 0;
    margin-left = 0;
    margin-right = 0;
    modules-left = [
      "custom/launcher"
      workspaceModule
      "tray"
    ];
    modules-center = ["clock"];
    modules-right = [
      "cpu"
      "memory"
      "pulseaudio"
      "battery"
      "custom/notification"
      "custom/nightlight"
      "custom/power-menu"
    ];
    clock = {
      calendar = {
        format = {
          today = "<span color='#98971A'><b>{}</b></span>";
        };
      };
      format = "{:%H:%M}";
      tooltip = "true";
      tooltip-format = "<big>{:%Y %B}</big>\n<tt><small>{calendar}</small></tt>";
      format-alt = "{:%d/%m}";
    };
    # workspace/tags module differs per compositor
    ${workspaceModule} =
      if compositor == "river"
      then {
        num-tags = 10;
        format = "{icon}";
        format-icons = ["I" "II" "III" "IV" "V" "VI" "VII" "VIII" "IX" "X"];
      }
      else {
        active-only = false;
        disable-scroll = true;
        format = "{icon}";
        on-click = "activate";
        sort-by-number = true;
        format-icons = {
          "1" = "I";
          "2" = "II";
          "3" = "III";
          "4" = "IV";
          "5" = "V";
          "6" = "VI";
          "7" = "VII";
          "8" = "VIII";
          "9" = "IX";
          "10" = "X";
        };
        persistent-workspaces = {
          "1" = [];
          "2" = [];
          "3" = [];
          "4" = [];
          "5" = [];
        };
      };
    cpu = {
      format = "<span foreground='${green}'> </span> {usage}%";
      format-alt = "<span foreground='${green}'> </span> {avg_frequency} GHz";
      interval = 2;
      on-click-right = btop;
    };
    memory = {
      format = "<span foreground='${cyan}'>󰟜 </span>{}%";
      format-alt = "<span foreground='${cyan}'>󰟜 </span>{used} GiB";
      interval = 2;
      on-click-right = btop;
    };
    tray = {
      icon-size = 20;
      spacing = 8;
    };
    pulseaudio = {
      format = "{icon} {volume}%";
      format-muted = "<span foreground='${blue}'> </span> {volume}%";
      format-icons = {
        default = ["<span foreground='${blue}'> </span>"];
      };
      scroll-step = 2;
      on-click = "pamixer -t";
      on-click-right = "pavucontrol";
    };
    battery = {
      format = "<span foreground='${yellow}'>{icon}</span> {capacity}%";
      format-icons = [
        " "
        " "
        " "
        " "
        " "
      ];
      format-charging = "<span foreground='${yellow}'> </span>{capacity}%";
      format-full = "<span foreground='${yellow}'> </span>{capacity}%";
      format-warning = "<span foreground='${yellow}'> </span>{capacity}%";
      interval = 5;
      states = {
        warning = 20;
      };
      format-time = "{H}h{M}m";
      tooltip = true;
      tooltip-format = "{time}";
    };
    "custom/launcher" = {
      format = "";
      on-click = "random-wallpaper";
      on-click-right = "${variables.launcher} -show drun";
      tooltip = "true";
      tooltip-format = "Random Wallpaper";
    };
    "custom/notification" = {
      tooltip = true;
      tooltip-format = "Notifications";
      format = "{icon}";
      format-icons = {
        notification = "<span foreground='${red}'><sup></sup></span>";
        none = "";
        dnd-notification = "<span foreground='${red}'><sup></sup></span>";
        dnd-none = "";
        inhibited-notification = "<span foreground='${red}'><sup></sup></span>";
        inhibited-none = "";
        dnd-inhibited-notification = "<span foreground='${red}'><sup></sup></span>";
        dnd-inhibited-none = "";
      };
      return-type = "json";
      exec-if = "which swaync-client";
      exec = "swaync-client -swb";
      on-click = "swaync-client -t -sw";
      on-click-right = "swaync-client -d -sw";
      escape = true;
    };
    "custom/nightlight" = {
      tooltip = true;
      tooltip-format = "{alt}";
      return-type = "json";
      exec = "toggle-nightlight status";
      on-click = "toggle-nightlight toggle";
      interval = 2;
      escape = true;
    };
    "custom/power-menu" = {
      tooltip = true;
      tooltip-format = "Power menu";
      format = "<span foreground='${red}'> </span>";
      on-click = "power-menu";
    };
  };
}
