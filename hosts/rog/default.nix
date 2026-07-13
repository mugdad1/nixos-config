{
  pkgs,
  config,
  lib,
  gpu,
  inputs,
  variables,
  ...
}: let
  power-profile-helper = pkgs.writeShellScriptBin "power-profile-helper" ''
    set -euo pipefail
    CARDWIRE="${config.services.cardwire.package}/bin/cardwire"
    MUX_PATH=/sys/devices/platform/asus-nb-wmi/gpu_mux_mode
    case "$1" in
      cardwire-set)   $CARDWIRE set "$2" ;;
      cardwire-block) $CARDWIRE gpu "$2" --block ;;
      mux)            echo "$2" > "$MUX_PATH" ;;
      *)              echo "unknown: $1" >&2; exit 1 ;;
    esac
  '';
in {
  imports = [
    ./hardware-configuration.nix
    ../../modules/core
    inputs.cardwire.nixosModules.default
  ];

  options.drivers.amd-nvidia-hybrid = {
    enable = lib.mkEnableOption "Enable AMD iGPU + NVIDIA dGPU (Prime offload)";
    amdgpuBusId = lib.mkOption {
      type = lib.types.str;
      default = variables.amdgpuBusId;
      description = "PCI Bus ID for AMD GPU";
    };
    nvidiaBusId = lib.mkOption {
      type = lib.types.str;
      default = variables.nvidiaBusId;
      description = "PCI Bus ID for NVIDIA dGPU";
    };
  };

  config = lib.mkMerge [
    (lib.mkIf (gpu == "amd-nvidia-hybrid") {
      environment.systemPackages = with pkgs; [
        nvtopPackages.full
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
            amdgpuBusId = config.drivers.amd-nvidia-hybrid.amdgpuBusId;
            nvidiaBusId = config.drivers.amd-nvidia-hybrid.nvidiaBusId;
          };
        };
      };
    })

    {
      services.xserver.videoDrivers = ["nvidia"];

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

      systemd.services.battery-threshold = {
        description = "Set battery charge threshold after asusd";
        after = ["asusd.service"];
        requires = ["asusd.service"];
        wantedBy = ["multi-user.target"];
        serviceConfig = {
          Type = "oneshot";
          ExecStart = "${pkgs.bash}/bin/bash -c 'echo 80 > /sys/class/power_supply/BAT0/charge_control_end_threshold'";
          ProtectSystem = "strict";
          ProtectHome = true;
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
        requires = ["cardwired.service"];
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

            # Re-apply GPU mode so it survives reboots
            if [ -f "$MODE_FILE" ]; then
              MODE=$(jq -r '.mode' "$MODE_FILE")
              if [ "$MODE" = "integrated" ] || [ "$MODE" = "hybrid" ] || [ "$MODE" = "manual" ]; then
                cardwire set "$MODE" 2>/dev/null || true
              fi
            else
              cardwire set hybrid 2>/dev/null || true
            fi

            # Set MUX switch based on the active mode
            if [ -f "$MODE_FILE" ] && [ -f "$MUX_PATH" ]; then
              MODE=$(jq -r '.mode' "$MODE_FILE")
              CURRENT_MUX=$(cat "$MUX_PATH")
              case "$MODE" in
                integrated)
                  if [ "$CURRENT_MUX" != "1" ]; then
                    echo 1 > "$MUX_PATH"
                  fi
                  ;;
                hybrid)
                  if [ "$CURRENT_MUX" != "1" ]; then
                    echo 1 > "$MUX_PATH"
                  fi
                  ;;
                manual)
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
        acpi
        (ffmpeg-full.override {withNvcodec = true;})
      ];

      security.wrappers.power-profile-helper = {
        owner = "root";
        group = "root";
        source = "${power-profile-helper}/bin/power-profile-helper";
      };
    }
  ];
}
