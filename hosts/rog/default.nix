{
  pkgs,
  config,
  lib,
  username,
  gpu,
  inputs,
  ...
}: let
  keyboard-brightness = "/sys/class/leds/asus::kbd_backlight/brightness";
  keyboard-lock = "/tmp/rog-kb-cycle.lock";
  keyboard-cycle-script = pkgs.writeShellScriptBin "rog-keyboard-cycle" ''
    BRIGHTNESS_PATH="${keyboard-brightness}"
    STEPS=15
    COLORS=(fb4934 fe8019 fabd2f b8bb26 83a598 458588 d3869b b16286)
    N=''${#COLORS[@]}

    hex() { printf '%02x%02x%02x' "$1" "$2" "$3"; }

    # Ensure keyboard backlight is on
    echo 3 > "$BRIGHTNESS_PATH" 2>/dev/null || true

    # Start paused - run rog-kb-toggle to begin
    touch ${keyboard-lock}

    while true; do
      if [ -f ${keyboard-lock} ]; then
        sleep 1
        continue
      fi

      for ((i = 0; i < N; i++)); do
        j=$(( (i + 1) % N ))
        c1=''${COLORS[i]}; c2=''${COLORS[j]}

        r1=$((16#''${c1:0:2})); g1=$((16#''${c1:2:2})); b1=$((16#''${c1:4:2}))
        r2=$((16#''${c2:0:2})); g2=$((16#''${c2:2:2})); b2=$((16#''${c2:4:2}))

        for ((s = 0; s <= STEPS; s++)); do
          [ -f ${keyboard-lock} ] && break 2
          rr=$(( r1 + (r2 - r1) * s / STEPS ))
          gg=$(( g1 + (g2 - g1) * s / STEPS ))
          bb=$(( b1 + (b2 - b1) * s / STEPS ))
          asusctl aura effect static -c "$(hex $rr $gg $bb)"
          sleep 0.05
        done

      done
    done
  '';
  keyboard-toggle-script = pkgs.writeShellScriptBin "rog-kb-toggle" ''
    BRIGHTNESS_PATH="${keyboard-brightness}"
    if [ -f ${keyboard-lock} ]; then
      rm -f ${keyboard-lock}
      echo 3 > "$BRIGHTNESS_PATH" 2>/dev/null || true
      echo "LED cycling ON"
    else
      touch ${keyboard-lock}
      asusctl aura effect static -c fb4934
      echo "LED cycling OFF"
    fi
  '';
in {
  imports = [
    ./hardware-configuration.nix
    ./../../modules/core
    inputs.cardwire.nixosModules.default
  ];

  options.drivers.amd-nvidia-hybrid = {
    enable = lib.mkEnableOption "Enable AMD iGPU + NVIDIA dGPU (Prime offload)";
    amdgpuBusId = lib.mkOption {
      type = lib.types.str;
      default = "PCI:5:0:0";
      description = "PCI Bus ID for AMD GPU";
    };
    nvidiaBusId = lib.mkOption {
      type = lib.types.str;
      default = "PCI:1:0:0";
      description = "PCI Bus ID for NVIDIA dGPU";
    };
  };

  config = lib.mkMerge [
    (lib.mkIf (gpu == "amd-nvidia-hybrid") {
      environment.systemPackages = with pkgs; [
        nvtopPackages.full
      ];

      hardware = {
        graphics.extraPackages = with pkgs; [
          libva
        ];

        nvidia = {
          modesetting.enable = true;
          open = true;
          package = config.boot.kernelPackages.nvidiaPackages.stable;
          powerManagement.enable = true;
          powerManagement.finegrained = true;

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
                charge_control_end_threshold: 80,
                base_charge_control_end_threshold: 80,
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

      boot.postBootCommands = ''
        echo 80 > /sys/class/power_supply/BAT0/charge_control_end_threshold
      '';

      systemd.services.battery-threshold = {
        description = "Set battery charge threshold after asusd";
        after = ["asusd.service"];
        requires = ["asusd.service"];
        wantedBy = ["multi-user.target"];
        serviceConfig = {
          Type = "oneshot";
          ExecStart = "${pkgs.bash}/bin/bash -c 'echo 80 > /sys/class/power_supply/BAT0/charge_control_end_threshold'";
        };
      };

      services.cardwire = {
        enable = true;
        settings = {
          auto_apply_gpu_state = true;
          experimental_nvidia_block = true;
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
              if [ "$MODE" = "integrated" ] || [ "$MODE" = "hybrid" ]; then
                cardwire set "$MODE" 2>/dev/null || true
              fi
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
        };
      };


      environment.systemPackages = with pkgs; [
        acpi
        keyboard-cycle-script
        keyboard-toggle-script
        (ffmpeg-full.override {withNvcodec = true;})
      ];

      systemd.user.services.rog-keyboard-cycle = {
        description = "Cycle ASUS keyboard LED through gruvbox colors";
        serviceConfig = {
          Type = "simple";
          ExecStart = "${keyboard-cycle-script}/bin/rog-keyboard-cycle";
          Restart = "on-failure";
          Environment = "PATH=/run/current-system/sw/bin:${pkgs.coreutils}/bin";
        };
        wantedBy = ["default.target"];
      };
    }
  ];
}
