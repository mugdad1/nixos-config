{
  pkgs,
  lib,
  config,
  ...
}: let
  g = (import ../../lib/gruvbox.nix).raw;

  greeterTheme = "container=#${g.bg0_h};border=#${g.green};text=#${g.fg};prompt=#${g.yellow};time=#${g.gray};action=#${g.blue};button=#${g.aqua};title=#${g.bright_blue};greet=#${g.bright_green};input=#${g.fg}";

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

    # GPU mode chosen by `gpu-mode`; the file only exists on victus. Cards are
    # found by PCI vendor id, because card numbering depends on load order.
    if [ -r /var/lib/victus/gpu-mode ]; then
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
      case "$(cat /var/lib/victus/gpu-mode)" in
        nvidia)
          # No MUX: the panel is wired to the iGPU, so keep Intel as the KMS
          # device and expose the dGPU for PRIME offload. Forcing the dGPU to
          # scan out gives a black screen.
          if [ -n "$intel_card" ]; then
            if [ -n "$nvidia_card" ]; then
              drm_devices="$intel_card:$nvidia_card"
            else
              drm_devices="$intel_card"
            fi
            export WLR_DRM_DEVICES="$drm_devices"
            export AQ_DRM_DEVICES="$drm_devices"
          else
            echo "gpu-mode: nvidia requested but no Intel DRM card found; leaving DRM device lists unset" >&2
          fi
          export __NV_PRIME_RENDER_OFFLOAD=1
          export __GLX_VENDOR_LIBRARY_NAME=nvidia
          export SWAY_UNSUPPORTED_GPU=true
          ;;
        intel)
          # HDMI is wired to the dGPU on this chassis, so "Intel only" still has
          # to hand the NVIDIA card to the compositor when an external display is
          # attached at login. Without it the port can never scan out.
          if [ -n "$intel_card" ] && [ -n "$nvidia_card" ] && card_has_display "''${nvidia_card##*/}"; then
            export WLR_DRM_DEVICES="$intel_card:$nvidia_card"
            export AQ_DRM_DEVICES="$intel_card:$nvidia_card"
            export SWAY_UNSUPPORTED_GPU=true
            # Do not restrict EGL to mesa here: the HDMI output needs the
            # NVIDIA vendor library to import its buffers.
            export __GLX_VENDOR_LIBRARY_NAME=mesa
          else
            if [ -n "$intel_card" ]; then
              export WLR_DRM_DEVICES="$intel_card"
              export AQ_DRM_DEVICES="$intel_card"
            fi
            # Hide the dGPU from userspace too, or glvnd opens the NVIDIA render
            # node and keeps the GPU awake.
            mesa_egl=/run/opengl-driver/share/glvnd/egl_vendor.d/50_mesa.json
            intel_vk=/run/opengl-driver/share/vulkan/icd.d/intel_icd.x86_64.json
            if [ -r "$mesa_egl" ]; then
              export __EGL_VENDOR_LIBRARY_FILENAMES="$mesa_egl"
            fi
            if [ -r "$intel_vk" ]; then
              export VK_DRIVER_FILES="$intel_vk"
              export VK_ICD_FILENAMES="$intel_vk"
            fi
            export __GLX_VENDOR_LIBRARY_NAME=mesa
            unset __NV_PRIME_RENDER_OFFLOAD __NV_PRIME_RENDER_OFFLOAD_PROVIDER __VK_LAYER_NV_optimus
          fi
          ;;
        hybrid)
          # Hand the dGPU to the compositor only when an external display is
          # attached (HDMI is wired to it). Neither compositor can add a DRM
          # device after startup, so a mid-session plug still needs a relogin.
          if [ -n "$intel_card" ]; then
            if [ -n "$nvidia_card" ] && card_has_display "''${nvidia_card##*/}"; then
              export WLR_DRM_DEVICES="$intel_card:$nvidia_card"
              export AQ_DRM_DEVICES="$intel_card:$nvidia_card"
              export SWAY_UNSUPPORTED_GPU=true
            else
              export WLR_DRM_DEVICES="$intel_card"
              export AQ_DRM_DEVICES="$intel_card"
            fi
          fi
          ;;
      esac
    fi

    exec "$@"
  '';
in {
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
}
