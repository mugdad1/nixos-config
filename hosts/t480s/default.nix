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
    extraPackages = with pkgs; [
      intel-media-driver
      intel-compute-runtime
    ];
  };

  boot.kernelParams = [
    "mem_sleep_default=deep"
    "psmouse.synaptics_intertouch=1"
    "preempt=voluntary"
    "nowatchdog"
    "psi=1"
    "rootflags=noatime"
    "fbcon=nodefer"
  ];

  services.throttled.enable = true;
  services.tlp.enable = false;
  services.power-profiles-daemon.enable = true;
  environment.systemPackages = [pkgs.powertop];

  # Oracle VM VirtualBox: enable adds the hardened virtualbox + setuid wrappers
  # automatically, so do NOT also add pkgs.virtualbox to systemPackages (that
  # would shadow it with an unhardened build and break /dev/vboxdrv access).
  virtualisation.virtualbox.host.enable = true;
  users.users.mugdad.extraGroups = ["vboxusers"];

  systemd.services.battery-threshold = {
    description = "Set battery charge threshold";
    after = ["multi-user.target"];
    wantedBy = ["multi-user.target"];
    serviceConfig = {
      Type = "oneshot";
      ExecStart = "${pkgs.bash}/bin/bash -c 'for bat in /sys/class/power_supply/BAT*; do [ -f \"$bat/charge_control_end_threshold\" ] && echo 85 > \"$bat/charge_control_end_threshold\"; done'";
      ProtectSystem = "strict";
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
