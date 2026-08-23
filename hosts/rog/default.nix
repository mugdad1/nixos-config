{
  pkgs,
  config,
  lib,
  inputs,
  username,
  ...
}: let
  power-profile-helper = pkgs.writeShellScriptBin "power-profile-helper" ''
    set -euo pipefail
    CARDWIRE="${config.services.cardwire.package}/bin/cardwire"
    MUX_PATH=/sys/devices/platform/asus-nb-wmi/gpu_mux_mode
    DESIRED_FILE=/etc/cardwire-desired-mode
    case "$1" in
      cardwire-set)   $CARDWIRE set "$2" ;;
      cardwire-block) $CARDWIRE gpu "$2" --block ;;
      # Persist the desired GPU mode and flip the hardware MUX. The manual
      # cardwire set below only succeeds AFTER rebooting (Desktop
      # classification in dGPU mode), so we only persist the intent here.
      mux)            echo "$2" > "$MUX_PATH" ;;
      desired-mode)   echo "$2" > "$DESIRED_FILE" ;;
      *)              echo "unknown: $1" >&2; exit 1 ;;
    esac
  '';
in {
  imports = [
    ./hardware-configuration.nix
    ../../modules/core
    inputs.cardwire.nixosModules.default
  ];

  boot.kernelParams = [
    "amd_pstate=active"
    "amd_iommu=force"
    "preempt=voluntary"
    "nowatchdog"
    "psi=1"
    "rootflags=noatime"
    "fbcon=nodefer"
  ];

  boot.blacklistedKernelModules = [
    "firewire-core"
  ];

  hardware = {
    nvidia = {
      modesetting.enable = true;
      open = true;
      package = config.boot.kernelPackages.nvidiaPackages.stable;

      prime = {
        offload = {
          enable = true;
          enableOffloadCmd = true;
        };
        amdgpuBusId = "PCI:5:0:0";
        nvidiaBusId = "PCI:1:0:0";
      };
    };
  };

  services.xserver.videoDrivers = ["nvidia"];

  # VirtualBox host: kernel modules (vboxdrv/vboxnetflt/vboxnetadp), udev
  # rules and setuid wrappers are all handled by this option. Do NOT also add
  # the virtualbox package to environment.systemPackages — that breaks driver
  # access (NS_ERROR_FAILURE). Extension pack is unfree but allowUnfree is set
  # in modules/core/system.nix; it provides USB 2/3 passthrough.
  virtualisation.virtualbox.host = {
    enable = true;
    enableExtensionPack = true;
  };
  users.extraGroups.vboxusers.members = [username];

  services.asusd = {
    enable = true;
    asusdConfig.text = ''
      (
          disable_nvidia_powerd_on_battery: true,
          platform_profile_linked_epp: true,
          platform_profile_on_battery: Quiet,
          change_platform_profile_on_battery: true,
          platform_profile_on_ac: Quiet,
          change_platform_profile_on_ac: true,
          profile_quiet_epp: Power,
          profile_balanced_epp: BalancePower,
          profile_custom_epp: Performance,
          profile_performance_epp: Performance,
      )
    '';
  };

  # asus-shutdown ignores SIGTERM (it defers exit until a real shutdown event)
  # and has SendSIGKILL=no from upstream, so restarting it during a
  # nixos-rebuild switch hangs and leaves a zombie process. Allow systemd to
  # kill it after the stop timeout; 90s still gives the deferred GPU firmware
  # apply (worst case ~45s) room to finish during a real shutdown.
  systemd.services.asus-shutdown.serviceConfig = {
    SendSIGKILL = true;
    TimeoutStopSec = "90";
  };

  systemd.services.battery-threshold = {
    description = "Set battery charge threshold after asusd";
    after = ["asusd.service"];
    requires = ["asusd.service"];
    wantedBy = ["multi-user.target"];
    serviceConfig = {
      Type = "oneshot";
      ExecStart = "${pkgs.bash}/bin/bash -c 'echo 80 > /sys/class/power_supply/BAT0/charge_control_end_threshold'";
      ProtectSystem = "strict";
      PrivateTmp = true;
      NoNewPrivileges = true;
      RestrictSUIDSGID = true;
    };
  };

  services.cardwire = {
    enable = true;
    settings = {
      auto_apply_gpu_state = true;
      experimental_nvidia_block = false;
      battery_auto_switch = false;
    };
  };

  systemd.services.cardwire-apply-blocks = {
    description = "Re-apply cardwire GPU mode, MUX, and block states after boot";
    after = ["cardwired.service"];
    wants = ["cardwired.service"];
    wantedBy = ["multi-user.target"];
    path = [
      config.services.cardwire.package
      pkgs.jq
      pkgs.coreutils
    ];
    serviceConfig = {
      Type = "oneshot";
      ExecStart = "${pkgs.writeShellScript "cardwire-apply-blocks" ''
        set -eu

        MODE_FILE=/var/lib/cardwire/mode.json
        STATE_FILE=/var/lib/cardwire/gpu_state.json
        MUX_PATH=/sys/devices/platform/asus-nb-wmi/gpu_mux_mode
        DESIRED_FILE=/etc/cardwire-desired-mode
        AMD_PCI=0000:06:00.0

        # Wait for cardwired to actually respond (it may still be starting up
        # after a boot-time restart while NVIDIA device nodes are created).
        for _ in $(seq 1 24); do
          if cardwire list --json >/dev/null 2>&1; then
            break
          fi
          sleep 5
        done

        # Persisted desired mode wins (set by the power-profile-helper), else
        # fall back to cardwire's own state.
        MODE=""
        if [ -f "$DESIRED_FILE" ]; then
          MODE=$(cat "$DESIRED_FILE")
          case "$MODE" in
            amd)
              cardwire set integrated 2>/dev/null || true
              ;;
            hybrid)
              cardwire set hybrid 2>/dev/null || true
              ;;
            nvidia)
              # In dGPU mode the system classifies as Desktop, so manual mode
              # and per-GPU blocking become available: block AMD.
              cardwire set manual 2>/dev/null || true
              AMD_ID=$(cardwire list --json | jq -r \
                "to_entries[] | select(.value.pci == \"$AMD_PCI\") | .value.id")
              [ -n "$AMD_ID" ] && cardwire gpu "$AMD_ID" --block 2>/dev/null || true
              ;;
          esac
        elif [ -f "$MODE_FILE" ]; then
          MODE=$(jq -r '.mode' "$MODE_FILE")
          case "$MODE" in
            integrated|hybrid|manual) cardwire set "$MODE" 2>/dev/null || true ;;
          esac
        else
          cardwire set hybrid 2>/dev/null || true
        fi

        # Set MUX switch based on the active mode
        if [ -f "$MUX_PATH" ]; then
          CURRENT_MUX=$(cat "$MUX_PATH")
          case "$MODE" in
            amd|hybrid|integrated)
              if [ "$CURRENT_MUX" != "1" ]; then
                echo 1 > "$MUX_PATH"
              fi
              ;;
            nvidia|manual)
              if [ "$CURRENT_MUX" != "0" ]; then
                echo 0 > "$MUX_PATH"
              fi
              ;;
          esac
        fi

        # Re-apply per-GPU blocks
        [ -f "$STATE_FILE" ] || exit 0
        BLOCKED=$(jq -r "to_entries[] | select(.value.block == true) | .key" "$STATE_FILE")
        for pci in $BLOCKED; do
          id=$(cardwire list --json | jq -r \
            "to_entries[] | select(.value.pci == \"$pci\") | .value.id")
          [ -n "$id" ] && cardwire gpu "$id" --block || true
        done
      ''}";
      ProtectSystem = "strict";
      ProtectHome = true;
      PrivateTmp = true;
      NoNewPrivileges = true;
      RestrictSUIDSGID = true;
    };
  };

  environment.systemPackages = with pkgs; [
    nvtopPackages.full
    acpi
    (ffmpeg-full.override {withNvcodec = true;})
    power-profile-helper
  ];

  # Privileged ops (MUX flip, desired-mode persist) run through pkexec with a
  # polkit rule instead of a setuid script wrapper (setuid is ignored on
  # shebang scripts).
  environment.etc."polkit-1/rules.d/10-power-profile-helper.rules".text = ''
    polkit.addRule(function(action, subject) {
      if (action.id == "org.freedesktop.policykit.exec" &&
          subject.user == "mugdad" &&
          action.lookup("program").endsWith("/power-profile-helper")) {
        return polkit.Result.YES;
      }
    });
  '';
}
