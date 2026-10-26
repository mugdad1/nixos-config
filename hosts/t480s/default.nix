{
  pkgs,
  inputs,
  ...
}: {
  imports = [
    inputs.nixos-hardware.nixosModules.lenovo-thinkpad-t480s
    ./hardware-configuration.nix
    ../../modules/core
    # Desktop is opt-in per host, no longer dragged in by core (2026-10-12).
    # This laptop wants a desktop.
    ../../modules/desktop
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
    "nowatchdog"
    "psi=1"
    "rootflags=noatime"
    "fbcon=nodefer"
  ];

  # throttled (lenovo-throttling-fix) fights power-profiles-daemon over the
  # CPU governor on Intel HWP; PPD + platform_profile is sufficient on this
  # BIOS gen. tlp is likewise off — PPD is the single power daemon.
  services.throttled.enable = false;
  services.tlp.enable = false;
  services.power-profiles-daemon.enable = true;
  # WHPH — his old productivity app (tasks/habits/timers) — is fully gone as
  # of 2026-10-20 on his "rm whph": both the ~/projects/whph clone and the
  # pkgs/whph.nix derivation are deleted, not merely commented out. Kept here
  # as a note only, so nobody re-adds it wondering. It was dropped because its
  # sync bound to whatever the laptop happened to be on and only lived while
  # the laptop was up — which is precisely what the self-hosted task store
  # replaces: Vikunja, which lived on the ThinkCentre (tailscale only,
  # http://100.88.29.31:3456/) until that box was returned 2026-10-22; the
  # task store is offline pending his word on a grandpa home. Tasks.org on
  # the phone, web UI on this machine (modules/home/apps/tasks.nix — the
  # desktop entry is commented out for the same reason).
  environment.systemPackages = [
    pkgs.powertop
    pkgs.tmux
  ];

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
