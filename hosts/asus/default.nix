# ASUS X509 (i3-8xxxU, 4 GiB, RTL8821CE) — headless Wi-Fi server. The OS lives
# on the SATA SSD; the 1 TB Seagate is a separate partition mounted at
# /srv/storage (2.5" bay or USB enclosure — both mount by label). Imports
# modules/core only, never modules/desktop.
{
  pkgs,
  username,
  ...
}: {
  imports = [
    ./hardware-configuration.nix
    ../../modules/core
    ./services.nix
  ];

  boot.loader.efi.efiSysMountPoint = "/boot";

  # Spinning, SMR platter is the only disk.
  boot.kernelParams = [
    "rootflags=noatime"
    "nowatchdog"
    "psi=1"
  ];

  # RTL8821CE (10ec:c821) is driven by the in-tree rtw88_8821ce; the
  # out-of-tree rtl8821ce package was dropped from nixpkgs. Both quirks below
  # cost this chip its link: PCIe ASPM drops it under load, deep power save
  # stalls it when idle. There is no wired uplink to fall back to.
  boot.kernelModules = ["rtw88_8821ce"];
  boot.extraModprobeConfig = ''
    options rtw88_pci disable_aspm=1
    options rtw88_core disable_lps_deep=1
  '';

  # 4 GiB with no desktop: compressed swap keeps the store off the platter.
  zramSwap = {
    enable = true;
    algorithm = "lz4";
    memoryPercent = 50;
    priority = 100;
  };

  # It is a server: closing the lid must not stop it, and nothing may suspend.
  services.logind.settings.Login = {
    HandleLidSwitch = "ignore";
    HandleLidSwitchExternalPower = "ignore";
    HandleLidSwitchDocked = "ignore";
  };
  systemd.targets.sleep.enable = false;
  systemd.targets.suspend.enable = false;
  systemd.targets.hibernate.enable = false;
  systemd.targets.hybrid-sleep.enable = false;

  # 24/7 on AC: a pack held at 100% swells within a year. ASUS exposes the
  # threshold through the standard sysfs attribute; write it if it is there.
  systemd.services."asus-charge-limit" = {
    description = "Cap the battery charge at 70%";
    wantedBy = ["multi-user.target"];
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
    };
    script = ''
      limit=/sys/class/power_supply/BAT0/charge_control_end_threshold
      if [ -w "$limit" ]; then
        echo 70 > "$limit"
        echo "asus: charge limited to 70%"
      else
        echo "asus: $limit missing; firmware exposes no charge limit" >&2
      fi
    '';
  };

  users.users.${username}.extraGroups = ["users"];

  environment.systemPackages = with pkgs; [
    iw
    rsync
  ];
}
