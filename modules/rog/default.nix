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
in
{
  services.asusd = {
    enable = true;
    asusdConfig.text = ''
      (
          charge_control_end_threshold: 100,
          base_charge_control_end_threshold: 100,
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
              "gpu_mux_mode": 1,
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

  services.supergfxd = {
    enable = true;
    settings = {
      vfio_enable = true;
      always_reboot = false;
      no_logind = false;
    };
  };

  boot.kernelPackages = lib.mkDefault pkgs.linuxPackages_latest;

  systemd.tmpfiles.rules = [
    "d /etc/asusd 0755 root root"
  ];

  environment.systemPackages = [ keyboard-cycle-script ];

  systemd.user.services.rog-keyboard-cycle = {
    description = "Cycle ASUS keyboard LED through gruvbox colors";
    serviceConfig = {
      Type = "simple";
      ExecStart = "${keyboard-cycle-script}/bin/rog-keyboard-cycle";
      Restart = "on-failure";
      Environment = "PATH=/run/current-system/sw/bin:/nix/store/9ypz3flqsrl5xl495mm8h645gadjsxi1-coreutils-9.11/bin";
    };
    wantedBy = [ "default.target" ];
  };
}
