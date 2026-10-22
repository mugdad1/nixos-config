{
  pkgs,
  lib,
  ...
}: let
  g = (import ../../lib/gruvbox.nix).raw;

  # greeter theme
  greeterTheme = "container=#${g.bg0_h};border=#${g.green};text=#${g.fg};prompt=#${g.yellow};time=#${g.gray};action=#${g.blue};button=#${g.aqua};title=#${g.bright_blue};greet=#${g.bright_green};input=#${g.fg}";
  # single-token session command (tuigreet -c would clobber --cmd).
  # Wrapper exports the Wayland session vars: greetd/tuigreet launch on a
  # bare TTY (XDG_SESSION_TYPE=tty, no CurrentDesktop), which breaks
  # portals, Electron/Ozone and anything keying off the desktop id.
  sessionCommand = pkgs.writeShellScript "sway-session" ''
    export XDG_SESSION_TYPE=wayland
    export XDG_SESSION_DESKTOP=sway
    export XDG_CURRENT_DESKTOP=sway
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
        for c in /dev/dri/card[0-9]*; do
          [ -r "$c/device/vendor" ] || continue
          if [ "$(cat "$c/device/vendor")" = "$1" ]; then
            printf '%s\n' "$c"
            return 0
          fi
        done
        return 1
      }
      intel_card="$(drm_card_for 0x8086 || true)"
      nvidia_card="$(drm_card_for 0x10de || true)"
      case "$(cat /var/lib/victus/gpu-mode)" in
        nvidia)
          # dGPU renders, iGPU stays in the list because the internal panel is
          # wired to it (no MUX on this chassis).
          if [ -n "$nvidia_card" ] && [ -n "$intel_card" ]; then
            export WLR_DRM_DEVICES="$nvidia_card:$intel_card"
            export GBM_BACKEND=nvidia-drm
            export __NV_PRIME_RENDER_OFFLOAD=1
            export __GLX_VENDOR_LIBRARY_NAME=nvidia
          else
            echo "gpu-mode: nvidia requested but no NVIDIA DRM card found; staying on Intel" >&2
          fi
          ;;
        intel | hybrid)
          if [ -n "$intel_card" ]; then
            export WLR_DRM_DEVICES="$intel_card"
          fi
          ;;
      esac
    fi
    exec ${pkgs.sway}/bin/sway
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

    udisks2.enable = true;

    greetd = {
      enable = true;
      settings = {
        default_session = {
          command = "${pkgs.tuigreet}/bin/tuigreet --time --asterisks --remember --theme '${greeterTheme}' --cmd ${sessionCommand}";
          user = "greeter";
        };
      };
    };

    irqbalance.enable = true;
    bpftune.enable = true;

    # sched_ext: EEVDF stays the in-kernel default, this swaps a BPF scheduler
    # in over it at runtime (kernel >= 6.12; ours is 7.2, and /sys/kernel/sched_ext
    # is what the unit conditions on). scx_bpfland is the interactive-aware one:
    # it sorts tasks by voluntary context-switch rate and prioritizes the
    # interactive queue, which is the laptop case — nix builds, indexing or
    # containers churning while you type.
    #
    # NOT scx_lavd, despite it being the usual "gaming" answer: its scheduling
    # domains are built per-LLC and per-core type (P/E, AMD CCDs), and a Kaby
    # Lake-R is a single homogeneous cluster, so its main advantage does not
    # apply here. A BORE/BMQ kernel was considered and rejected too — same
    # reasoning, and it would mean replacing the mainline kernel for gains that
    # show up mostly on heterogeneous CPUs.
    #
    # If the scheduler process dies, the kernel falls back to EEVDF by itself;
    # disabling this option and rebuilding undoes it entirely.
    scx = {
      enable = true;
      scheduler = "scx_bpfland";
    };
  };

  # tuigreet's --remember cache; lives here (not shared boot.nix) because
  # the `greeter` user only exists where greetd runs.
  systemd.tmpfiles.rules = [
    "d /var/cache/tuigreet 0755 greeter greeter"
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
}
