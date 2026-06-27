{
  pkgs,
  config,
  lib,
  username,
  gpu,
  ...
}: let
  keyboard-cycle-script = pkgs.writeShellScriptBin "rog-keyboard-cycle" ''
    STEPS=15
    COLORS=(fb4934 fe8019 fabd2f b8bb26 83a598 458588 d3869b b16286)
    N=''${#COLORS[@]}

    hex() { printf '%02x%02x%02x' "$1" "$2" "$3"; }

    while true; do
      for ((i = 0; i < N; i++)); do
        j=$(( (i + 1) % N ))
        c1=''${COLORS[i]}; c2=''${COLORS[j]}

        r1=$((16#''${c1:0:2})); g1=$((16#''${c1:2:2})); b1=$((16#''${c1:4:2}))
        r2=$((16#''${c2:0:2})); g2=$((16#''${c2:2:2})); b2=$((16#''${c2:4:2}))

        for ((s = 0; s <= STEPS; s++)); do
          rr=$(( r1 + (r2 - r1) * s / STEPS ))
          gg=$(( g1 + (g2 - g1) * s / STEPS ))
          bb=$(( b1 + (b2 - b1) * s / STEPS ))
          asusctl aura effect static -c "$(hex $rr $gg $bb)"
          sleep 0.05
        done

      done
    done
  '';
in {
  imports = [
    ./hardware-configuration.nix
    ./../../modules/core
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

      services.cardwire = {
        enable = true;
        settings = {
          auto_apply_gpu_state = true;
          experimental_nvidia_block = true;
          battery_auto_switch = false;
        };
      };

      systemd.services.cardwire-apply-blocks = {
        description = "Re-apply cardwire GPU block states after boot";
        after = ["cardwired.service"];
        requires = ["cardwired.service"];
        wantedBy = ["multi-user.target"];
        path = [
          config.services.cardwire.package
          pkgs.jq
        ];
        serviceConfig = {
          Type = "oneshot";
          ExecStart = "${pkgs.writeShellScript "cardwire-apply-blocks" ''
            set -eu
            STATE=/var/lib/cardwire/gpu_state.json
            [ -f "$STATE" ] || exit 0
            BLOCKED=$(jq -r "to_entries[] | select(.value.block == true) | .key" "$STATE")
            for pci in $BLOCKED; do
              id=$(cardwire list --json | jq -r \
                "to_entries[] | select(.value.pci == \"$pci\" and .value.default == false) | .value.id")
              [ -n "$id" ] && cardwire gpu "$id" --block || true
            done
          ''}";
        };
      };

      powerManagement.powertop.enable = true;

      environment.systemPackages = with pkgs; [
        acpi
        keyboard-cycle-script
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

      home-manager.users.${username} = {
        wayland.windowManager.hyprland.settings.monitor = lib.mkDefault [
          "eDP-1,1920x1080@60,0x0,1.2"
          "eDP-2,1920x1080@60,0x0,1.2"
        ];
      };
    }
  ];
}
