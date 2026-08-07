{
  pkgs,
  inputs,
  ...
}: {
  imports = [
    inputs.nixos-hardware.nixosModules.lenovo-thinkpad-t480s
    ./hardware-configuration.nix
    ../../modules/core
  ];

  hardware.graphics = {
    enable = true;
    extraPackages = with pkgs; [
      intel-media-driver
      intel-compute-runtime
    ];
  };

  boot.kernelParams = [
    "i915.enable_guc=2"
    "i915.enable_fbc=1"
    "i915.enable_psr=2"
    "i915.enable_dc=2"
    "mem_sleep_default=deep"
    "psmouse.synaptics_intertouch=1"
  ];

  services.throttled.enable = true;
  services.tlp.enable = false;

  systemd.services.battery-threshold = {
    description = "Set battery charge threshold";
    after = ["multi-user.target"];
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

  services.logind.settings.Login = {
    HandleLidSwitch = "suspend";
    HandleLidSwitchExternalPower = "ignore";
  };

  environment.etc."libinput/local-overrides.quirks".text = ''
    [Trackpoint Buttons Only]
    MatchName=*Elan TrackPoint*
    AttrEventCode=-REL_X;-REL_Y
  '';

  environment.sessionVariables = {
    LIBVA_DRIVER_NAME = "iHD";
  };
}
