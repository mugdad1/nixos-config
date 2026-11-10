{
  pkgs,
  lib,
  config,
  ...
}: let
  g = (import ../../lib/gruvbox.nix).raw;

  # greeter theme
  greeterTheme = "container=#${g.bg0_h};border=#${g.green};text=#${g.fg};prompt=#${g.yellow};time=#${g.gray};action=#${g.blue};button=#${g.aqua};title=#${g.bright_blue};greet=#${g.bright_green};input=#${g.fg}";

  # tuigreet's --session-wrapper prepends this single-token command to the
  # Exec line of the desktop file the user picked. It exports the Wayland
  # session vars (greetd starts on a bare TTY: XDG_SESSION_TYPE=tty and no
  # CurrentDesktop, which breaks portals, Electron/Ozone and anything keying
  # off the desktop id) and the GPU selection, then execs the compositor.
  #
  # The desktop id is derived from the Exec basename, because both sessions
  # share one wrapper. Sway and Hyprland have different GPU backends but we
  # export both device lists: WLR_DRM_DEVICES is read by sway/wlroots,
  # AQ_DRM_DEVICES by aquamarine/Hyprland. Each compositor ignores the other.
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

    # GPU mode chosen by `gpu-mode` (hosts/victus/default.nix). The file only
    # exists on the Victus, so this is a no-op everywhere else. Cards are found
    # by PCI vendor id (0x8086 Intel, 0x10de NVIDIA) instead of card0/card1:
    # the numbering depends on module load order, the vendor does not.
    if [ -r /var/lib/victus/gpu-mode ]; then
      drm_card_for() {
        # Vendor lives in sysfs: /dev/dri/cardN is a character device, so
        # /dev/dri/cardN/device/vendor does not exist ("Not a directory").
        for d in /sys/class/drm/card[0-9]*; do
          [ -r "$d/device/vendor" ] || continue
          card="''${d##*/}"
          # skip connectors (card2-eDP-1 etc.), keep card nodes only
          [ -c "/dev/dri/$card" ] || continue
          if [ "$(cat "$d/device/vendor")" = "$1" ]; then
            printf '/dev/dri/%s\n' "$card"
            return 0
          fi
        done
        return 1
      }
      # True if any connector on the given card (e.g. card0) reports a
      # connected display. Used to decide whether the dGPU must be handed to
      # the compositor at login: HDMI on this chassis is wired to the NVIDIA
      # card, and Sway 1.12 ignores wlroots' add_drm_card signal, so a card
      # that is not in WLR_DRM_DEVICES at startup can never gain an output
      # later. Hyprland/aquamarine has the same startup-only behaviour.
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
          # The internal panel is wired to the iGPU; this chassis has no MUX.
          # wlroots cannot use the dGPU as the primary renderer while the
          # Intel GPU scans out eDP-1: it fails to pick an output format,
          # disables the panel, and leaves a black screen (sometimes only a
          # cursor). Keep Intel as the KMS/scanout device and expose the dGPU
          # for PRIME offload instead. NVIDIA still handles HDMI through the
          # second card, but it does not render the compositor.
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
          # Sway detects "nvidia-drm" as an unsupported proprietary driver
          # and pops a swaynag on every login. This chassis intentionally
          # keeps the module loaded; opt in instead of dismissing the nag.
          export SWAY_UNSUPPORTED_GPU=true
          ;;
        intel)
          if [ -n "$intel_card" ]; then
            export WLR_DRM_DEVICES="$intel_card"
            export AQ_DRM_DEVICES="$intel_card"
          fi
          # Hide the dGPU from userspace as well as the kernel. Without this,
          # glvnd enumerates every EGL vendor and the compositor/apps open the
          # NVIDIA render node even though the DRM device list points at the
          # Intel card, which keeps the modules pinned and the GPU wakeable.
          mesa_egl=/run/opengl-driver/share/glvnd/egl_vendor.d/50_mesa.json
          intel_vk=/run/opengl-driver/share/vulkan/icd.d/intel_icd.x86_64.json
          if [ -r "$mesa_egl" ]; then
            export __EGL_VENDOR_LIBRARY_FILENAMES="$mesa_egl"
          fi
          if [ -r "$intel_vk" ]; then
            # VK_ICD_FILENAMES is the old name; newer loaders use VK_DRIVER_FILES.
            export VK_DRIVER_FILES="$intel_vk"
            export VK_ICD_FILENAMES="$intel_vk"
          fi
          export __GLX_VENDOR_LIBRARY_NAME=mesa
          unset __NV_PRIME_RENDER_OFFLOAD __NV_PRIME_RENDER_OFFLOAD_PROVIDER __VK_LAYER_NV_optimus
          ;;
        hybrid)
          # dGPU modules stay loaded, but nothing should open them by default.
          # `nvidia-offload` sets the PRIME variables for the one command that
          # asks for the dGPU.
          if [ -n "$intel_card" ]; then
            if [ -n "$nvidia_card" ] && card_has_display "''${nvidia_card##*/}"; then
              # An external display is attached and HDMI is wired to the
              # dGPU, so expose the card to the compositor or the monitor can
              # never be turned on. Opening its DRM node keeps the dGPU awake
              # for this session; with no display attached only the iGPU is
              # opened and the dGPU still reaches D3cold. Neither compositor
              # can add a DRM device after startup, so plugging the cable in
              # mid-session still needs a logout/login.
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
      # don’t shutdown when power button is short-pressed
      HandlePowerKey = "ignore";

      # ignore lid close (hosts override with a plain definition, which takes
      # precedence over this mkDefault)
      HandleLidSwitch = lib.mkDefault "ignore";
      HandleLidSwitchExternalPower = lib.mkDefault "ignore";
      HandleLidSwitchDocked = lib.mkDefault "ignore";
    };

    greetd = {
      enable = true;
      settings = {
        default_session = {
          # Sessions come from /etc/wayland-sessions, which holds our two
          # entries (Sway and Hyprland). Passing --sessions keeps tuigreet out
          # of the system XDG dirs, so hyprland's own hyprland-uwsm.desktop
          # never shows up as a third, broken choice. --remember-session
          # selects the last session tuigreet wrote; tmpfiles seeds that file
          # with sway so a fresh install logs into Sway.
          command = "${pkgs.tuigreet}/bin/tuigreet --time --asterisks --remember --remember-session --sessions /etc/wayland-sessions --session-wrapper ${sessionWrapper} --theme '${greeterTheme}'";
          user = "greeter";
        };
      };
    };

    # irqbalance and bpftune OFF since 2026-11-02. Both are server/experiment
    # tools: irqbalance regularly makes desktop IRQ placement worse (it has a
    # long regression history) and bpftune rewrites sysctls at runtime behind
    # your back, so the machine stops being reproducible. `scx_bpfland` below
    # is the scheduler that actually helps an interactive laptop.
    irqbalance.enable = false;
    bpftune.enable = false;

    # sched_ext: EEVDF stays the in-kernel default, this swaps a BPF scheduler
    # in over it at runtime (kernel >= 6.12; ours is 7.3, and /sys/kernel/sched_ext
    # is what the unit conditions on). scx_bpfland is the interactive-aware one:
    # it sorts tasks by voluntary context-switch rate and prioritizes the
    # interactive queue, which is the laptop case — nix builds, indexing or
    # containers churning while you type.
    #
    # NOT scx_lavd, despite it being the usual "gaming" answer: lavd splits
    # domains per-LLC and per-core type and tunes for latency-critical games,
    # while this laptop mostly runs builds, containers and a browser alongside
    # typing — the interactive queue is the thing to protect here. A BORE/BMQ
    # kernel was considered and rejected too: same reasoning, and it would mean
    # replacing the mainline kernel for a marginal scheduler change.
    #
    # If the scheduler process dies, the kernel falls back to EEVDF by itself;
    # disabling this option and rebuilding undoes it entirely.
    scx-loader = {
      enable = true;
      config.default_sched = "scx_bpfland";
    };
  };

  # The two compositor sessions offered at greetd. Both Exec lines go through
  # the same wrapper; DesktopNames is what tuigreet turns into
  # XDG_CURRENT_DESKTOP/XDG_SESSION_DESKTOP for portals.
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

  # gvfs 1.48+ spawns `wsdd` itself when a file manager browses the Windows
  # Network neighbourhood. Without it, Nautilus/Nemo show "Failed to spawn the
  # wsdd daemon" and the SMB workgroup comes up empty.
  environment.systemPackages = [pkgs.wsdd];

  # tuigreet's --remember/--remember-session cache; lives here (not shared
  # boot.nix) because the `greeter` user only exists where greetd runs.
  #
  # `f` only writes the file when it is missing, so the session the user
  # actually picked survives reboots. `r` drops a stale free-form command
  # (lastsession) left over from the old --cmd setup; if present, tuigreet
  # would prefer it over the session file.
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

  # systemd-oomd ships enabled but does nothing until a slice opts in: the
  # NixOS defaults leave root/system/user slices unmanaged. On 8 GB + zram the
  # failure mode to avoid is the whole desktop locking up under pressure, so
  # let oomd kill the largest process in the user slice at 80% pressure
  # (Fedora's default policy). System/root slices stay unmanaged on purpose:
  # killing a daemon is worse than killing a browser tab.
  systemd.oomd = {
    enable = true;
    enableUserSlices = true;
  };
}
