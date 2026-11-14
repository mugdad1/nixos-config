{
  pkgs,
  lib,
  config,
  ...
}: let
  cfg = config.services.desktop;
  g = (import ../../lib/gruvbox.nix).raw;

  greeterTheme = "container=#${g.bg0_h};border=#${g.green};text=#${g.fg};prompt=#${g.yellow};time=#${g.gray};action=#${g.blue};button=#${g.aqua};title=#${g.bright_blue};greet=#${g.bright_green};input=#${g.fg}";

  # Only needed on machines where the panel hangs off the iGPU and an external
  # port hangs off the dGPU (the Victus): the compositor has to be told both
  # DRM nodes up front, because neither sway nor Hyprland can add a device
  # after startup. Everywhere else the compositor picks its own nodes.
  gpuDevices = lib.optionalString cfg.intelPrimaryDrm ''
    # Cards are found by PCI vendor id, because card numbering depends on load
    # order.
    drm_card_for() {
      for d in /sys/class/drm/card[0-9]*; do
        [ -r "$d/device/vendor" ] || continue
        card="''${d##*/}"
        [ -c "/dev/dri/$card" ] || continue
        if [ "$(cat "$d/device/vendor")" = "$1" ]; then
          printf '/dev/dri/%s\n' "$card"
          return 0
        fi
      done
      return 1
    }
    # True if any connector on the given card reports a connected display.
    card_has_display() {
      for c in /sys/class/drm/"$1"-*/status; do
        [ -r "$c" ] || continue
        if [ "$(cat "$c")" = connected ]; then
          return 0
        fi
      done
      return 1
    }
    intel_card="$(drm_card_for 0x8086 || true)"
    nvidia_card="$(drm_card_for 0x10de || true)"
    if [ -n "$intel_card" ]; then
      if [ -n "$nvidia_card" ] && card_has_display "''${nvidia_card##*/}"; then
        export WLR_DRM_DEVICES="$intel_card:$nvidia_card"
        export AQ_DRM_DEVICES="$intel_card:$nvidia_card"
        export SWAY_UNSUPPORTED_GPU=true
      else
        export WLR_DRM_DEVICES="$intel_card"
        export AQ_DRM_DEVICES="$intel_card"
        # Nothing is plugged into the dGPU, so keep glvnd away from it: a
        # single open /dev/nvidia* handle pins the GPU in D0 and defeats
        # runtime D3. `nvidia-offload` overrides these for one command.
        mesa_egl=/run/opengl-driver/share/glvnd/egl_vendor.d/50_mesa.json
        if [ -r "$mesa_egl" ]; then
          export __EGL_VENDOR_LIBRARY_FILENAMES="$mesa_egl"
        fi
        export __GLX_VENDOR_LIBRARY_NAME=mesa
        unset __NV_PRIME_RENDER_OFFLOAD __NV_PRIME_RENDER_OFFLOAD_PROVIDER __VK_LAYER_NV_optimus
      fi
    fi
  '';

  # Shared greetd session wrapper: exports the Wayland session vars and the GPU
  # selection, then execs the compositor. WLR_DRM_DEVICES is read by sway,
  # AQ_DRM_DEVICES by Hyprland; each ignores the other.
  sessionWrapper = pkgs.writeShellScript "wayland-session" ''
    case "''${1##*/}" in
      start-hyprland | hyprland)
        export XDG_SESSION_DESKTOP=Hyprland
        export XDG_CURRENT_DESKTOP=Hyprland
        ;;
      *)
        export XDG_SESSION_DESKTOP=sway
        export XDG_CURRENT_DESKTOP=sway
        ;;
    esac

    export XDG_SESSION_TYPE=wayland
    export GDK_BACKEND=wayland
    export QT_QPA_PLATFORM=wayland
    export NIXOS_OZONE_WL=1
    export ELECTRON_OZONE_PLATFORM_HINT=wayland

    ${gpuDevices}

    exec "$@"
  '';
in {
  options.services.desktop.intelPrimaryDrm = lib.mkEnableOption ''
    explicit Wayland DRM device lists for an iGPU-scanned-out laptop whose
    external port is wired to the dGPU (Victus: no MUX, HDMI on the RTX 3050)
  '';

  config = {
    services = {
      gvfs.enable = true;

      gnome = {
        gnome-keyring.enable = true;
      };

      fstrim = {
        enable = true;
        interval = "daily";
      };
      fwupd.enable = true;

      logind.settings.Login = {
        HandlePowerKey = "ignore";
        HandleLidSwitch = lib.mkDefault "ignore";
        HandleLidSwitchExternalPower = lib.mkDefault "ignore";
        HandleLidSwitchDocked = lib.mkDefault "ignore";
      };

      greetd = {
        enable = true;
        settings = {
          default_session = {
            # Sessions come from /etc/wayland-sessions so hyprland's own
            # hyprland-uwsm.desktop never appears as a third, broken choice.
            command = "${pkgs.tuigreet}/bin/tuigreet --time --asterisks --remember --remember-session --sessions /etc/wayland-sessions --session-wrapper ${sessionWrapper} --theme '${greeterTheme}'";
            user = "greeter";
          };
        };
      };

      irqbalance.enable = false;
      bpftune.enable = false;

      # sched_ext: scx_bpfland prioritizes the interactive queue, which is the
      # laptop case (builds and containers churning while you type).
      scx-loader = {
        enable = true;
        config.default_sched = "scx_bpfland";
      };
    };

    # The two compositor sessions offered at greetd.
    environment.etc = {
      "wayland-sessions/sway.desktop".text = ''
        [Desktop Entry]
        Name=Sway
        Comment=i3-compatible Wayland compositor
        Exec=${pkgs.sway}/bin/sway
        Type=Application
        DesktopNames=sway
        Keywords=tiling;wayland;compositor;
      '';

      "wayland-sessions/hyprland.desktop".text = ''
        [Desktop Entry]
        Name=Hyprland
        Comment=An intelligent dynamic tiling Wayland compositor
        Exec=${config.programs.hyprland.package}/bin/start-hyprland
        Type=Application
        DesktopNames=Hyprland
        Keywords=tiling;wayland;compositor;
      '';
    };

    # gvfs needs wsdd to browse the Windows Network neighbourhood.
    environment.systemPackages = [pkgs.wsdd];

    # tuigreet's --remember-session cache. `f` only writes when missing, so the
    # picked session survives reboots; `r` drops a stale free-form command.
    systemd.tmpfiles.rules = [
      "d /var/cache/tuigreet 0755 greeter greeter -"
      "f /var/cache/tuigreet/lastsession-path 0644 greeter greeter - /etc/wayland-sessions/sway.desktop"
      "r /var/cache/tuigreet/lastsession"
    ];

    services.upower = {
      enable = true;
      percentageLow = 20;
      percentageCritical = 5;
      percentageAction = 3;
      criticalPowerAction = "PowerOff";
    };

    zramSwap = {
      enable = true;
      algorithm = "zstd";
    };

    # oomd only acts on slices that opt in; kill the largest user process at 80%
    # pressure rather than locking up the whole desktop.
    systemd.oomd = {
      enable = true;
      enableUserSlices = true;
    };
  };
}
