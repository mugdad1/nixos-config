{
  pkgs,
  config,
  lib,
  username,
  gpu,
  inputs,
  ...
}: {
  imports = [
    inputs.nixos-hardware.nixosModules.lenovo-thinkpad-t480s
    ./hardware-configuration.nix
    ../../modules/core
  ];

  hardware.intelgpu = {
    computeRuntime = "legacy";
    vaapiDriver = "intel-media-driver";
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
