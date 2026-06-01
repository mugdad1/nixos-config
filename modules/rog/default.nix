{ lib, pkgs, config, ... }:
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
          armoury_settings: {},
      )
    '';
  };

  boot.kernelPackages = lib.mkDefault pkgs.linuxPackages_latest;

  systemd.tmpfiles.rules = [
    "d /etc/asusd 0755 root root"
  ];
}
