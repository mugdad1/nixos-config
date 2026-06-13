{ lib, pkgs, config, ... }:
let
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

  gpu-tui-script = pkgs.writeShellScriptBin "gpu-tui" (builtins.readFile ./gpu-tui.sh);

in
{
  services.asusd = {
    enable = true;
    package = pkgs.asusctl.overrideAttrs (old: {
      postInstall = (old.postInstall or "") + ''
        rm -f $out/share/applications/rog-control-center.desktop
      '';
    });
    asusdConfig.text = ''
      (
            charge_control_end_threshold: 80,
            base_charge_control_end_threshold: 80,
          disable_nvidia_powerd_on_battery: true,
          ac_command: "",
          bat_command: "",
          platform_profile_linked_epp: true,
          platform_profile_on_battery: Quiet,
          change_platform_profile_on_battery: true,
          platform_profile_on_ac: Performance,
          change_platform_profile_on_ac: true,
          profile_quiet_epp: Power,
          profile_balanced_epp: BalancePower,
          profile_custom_epp: Performance,
          profile_performance_epp: Performance,
          ac_profile_tunings: {},
          dc_profile_tunings: {},
          armoury_settings: {
          },
          keyboard: (
              led_brightness: 1,
              aura: {
                  "main": (
                      mode: Static,
                      color1: (214, 93, 14),
                      color2: (0, 0, 0),
                      color3: (0, 0, 0),
                      speed: Low,
                  ),
              },
          ),
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
    after = [ "cardwired.service" ];
    requires = [ "cardwired.service" ];
    wantedBy = [ "multi-user.target" ];
    path = [ config.services.cardwire.package pkgs.jq ];
    serviceConfig = {
      Type = "oneshot";
      ExecStart = "${pkgs.writeShellScript "cardwire-apply-blocks" ''
        BLOCKED=$(jq -r "to_entries[] | select(.value.block == true) | .key" \
          /var/lib/cardwire/gpu_state.json 2>/dev/null)
        for pci in $BLOCKED; do
          id=$(cardwire list --json | jq -r \
            "to_entries[] | select(.value.pci == \"$pci\" and .value.default == false) | .value.id")
          [ -n "$id" ] && cardwire gpu "$id" --block
        done
      ''}";
    };
  };

  boot.kernelPackages = lib.mkDefault pkgs.linuxPackages_latest;

  systemd.tmpfiles.rules = [
    "d /etc/asusd 0755 root root"
  ];

  environment.systemPackages = with pkgs; [
    keyboard-cycle-script
    gpu-tui-script
    dialog
  ];

  systemd.user.services.rog-keyboard-cycle = {
    description = "Cycle ASUS keyboard LED through gruvbox colors";
    serviceConfig = {
      Type = "simple";
      ExecStart = "${keyboard-cycle-script}/bin/rog-keyboard-cycle";
      Restart = "on-failure";
      Environment = "PATH=/run/current-system/sw/bin:${pkgs.coreutils}/bin";
    };
    wantedBy = [ "default.target" ];
  };
}
