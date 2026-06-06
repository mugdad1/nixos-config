{ host, ... }:
let
  custom = import ./theme.nix;
in
{
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
      "hyprland/workspaces"
      "tray"
    ];
    modules-center = [ "clock" ];
    modules-right = [
      "cpu"
      "memory"
      "temperature"
      "custom/gpu-temp"
      "pulseaudio"
      "network"
      "battery"
      "hyprland/language"
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
    "hyprland/workspaces" = {
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
        "1" = [ ];
        "2" = [ ];
        "3" = [ ];
        "4" = [ ];
        "5" = [ ];
      };
    };
    cpu = {
      format = "<span foreground='${green}'> </span> {usage}%";
      format-alt = "<span foreground='${green}'> </span> {avg_frequency} GHz";
      interval = 2;
      on-click-right = "hyprctl dispatch exec '[float; center; size 950 650] kitty --override font_size=14 --title float_kitty btop'";
    };
    memory = {
      format = "<span foreground='${cyan}'>󰟜 </span>{}%";
      format-alt = "<span foreground='${cyan}'>󰟜 </span>{used} GiB"; # 
      interval = 2;
      on-click-right = "hyprctl dispatch exec '[float; center; size 950 650] kitty --override font_size=14 --title float_kitty btop'";
    };
    temperature = {
      thermal-zone = 0;
      format = "<span foreground='${orange}'>󰔄 </span>{temperatureC}°C";
      interval = 5;
    };
    "custom/gpu-temp" = {
      exec = "nvidia-smi --query-gpu=temperature.gpu --format=csv,noheader,nounits 2>/dev/null || echo 'N/A'";
      interval = 10;
      format = "<span foreground='${green}'> </span>{}°C";
      tooltip = false;
    };
    network = {
      format-wifi = "<span foreground='${magenta}'> </span> {signalStrength}%";
      format-ethernet = "<span foreground='${magenta}'>󰀂 </span>";
      tooltip-format = "Connected to {essid} {ifname} via {gwaddr}";
      format-linked = "{ifname} (No IP)";
      format-disconnected = "<span foreground='${magenta}'>󰖪 </span>";
    };
    tray = {
      icon-size = 20;
      spacing = 8;
    };
    pulseaudio = {
      format = "{icon} {volume}%";
      format-muted = "<span foreground='${blue}'> </span> {volume}%";
      format-icons = {
        default = [ "<span foreground='${blue}'> </span>" ];
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
    "hyprland/language" = {
      tooltip = true;
      tooltip-format = "Keyboard layout";
      format = "<span foreground='${yellow}'> </span> {}";
      format-fr = "FR";
      format-en = "US";
      on-click = "hyprctl switchxkblayout at-translated-set-2-keyboard next";
    };
    "custom/launcher" = {
      format = "";
      on-click = "random-wallpaper";
      on-click-right = "rofi -show drun";
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
      tooltip-format = "Toggle night light";
      return-type = "json";
      exec = "toggle-nightlight status";
      on-click = "toggle-nightlight toggle";
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
