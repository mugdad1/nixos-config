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
              export WLR_DRM_DEVICES="$intel_card:$nvidia_card"
            else
              export WLR_DRM_DEVICES="$intel_card"
            fi
          else
            echo "gpu-mode: nvidia requested but no Intel DRM card found; leaving WLR_DRM_DEVICES unset" >&2
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
          fi
          # Hide the dGPU from userspace as well as the kernel. Without this,
          # glvnd enumerates every EGL vendor and sway/apps open the NVIDIA
          # render node even though WLR_DRM_DEVICES points at the Intel card,
          # which keeps the modules pinned and the GPU wakeable.
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
    scx = {
      enable = true;
      scheduler = "scx_bpfland";
    };
  };

  # gvfs 1.48+ spawns `wsdd` itself when a file manager browses the Windows
  # Network neighbourhood. Without it, Nautilus/Nemo show "Failed to spawn the
  # wsdd daemon" and the SMB workgroup comes up empty.
  environment.systemPackages = [pkgs.wsdd];

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
