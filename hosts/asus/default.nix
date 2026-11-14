# ASUS X509 (i3-8xxxU, 4 GiB, RTL8821CE) — headless Wi-Fi server. The OS lives
# on the SATA SSD; the 1 TB Seagate is mounted at /srv/storage. Imports
# modules/core only, never modules/desktop.
{
  lib,
  pkgs,
  username,
  ...
}: {
  imports = [
    ./hardware-configuration.nix
    ../../modules/core
    ./packages.nix
    ./study.nix
  ];

  boot.loader.efi.efiSysMountPoint = "/boot";

  # The root disk is an SSD; the platter is storage only.
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

  # The 1 TB disk. Label, not UUID, so the disk can move to a USB enclosure
  # without editing anything; nofail so a dead platter never blocks boot.
  fileSystems."/srv/storage" = {
    device = "/dev/disk/by-label/asus-storage";
    fsType = "ext4";
    options = ["nofail" "x-systemd.device-timeout=10"];
  };

  # 4 GiB with no desktop: compressed swap keeps the store off the platter.
  zramSwap = {
    enable = true;
    algorithm = "lz4";
    memoryPercent = 50;
    priority = 100;
  };

  # Garbage collection is already fleet-wide: modules/core/nh.nix enables
  # programs.nh.clean (weekly, --keep-since 14d --keep 10). Turning on
  # nix.gc.automatic as well would run a second collector against the same
  # store, so it stays off here too.

  # smartctl is installed, but nothing watches the 1 TB platter until smartd
  # does. No mail transport on this box: findings land in the journal.
  services.smartd = {
    enable = true;
    notifications.wall.enable = false;
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

  # Same resolver as grandpa: this box is also at home, where DoT/DoQ are not
  # blocked, so it races the encrypted transports itself instead of DoH, and
  # answers the LAN as well as loopback. Kept in sync with
  # hosts/grandpa/overrides.nix.
  services.blocky.settings.upstreams.groups.default = lib.mkForce [
    "tcp-tls:cbf8aa.dns.nextdns.io:853"
    "quic:2b44bd66.d.adguard-dns.com"
  ];
  services.blocky.settings.ports.dns = lib.mkForce "0.0.0.0:53";
  networking.firewall.allowedTCPPorts = [53];
  networking.firewall.allowedUDPPorts = [53];

  users.users.${username} = {
    extraGroups = ["users"];

    # victus holds the only keypair in the fleet; key auth means no password
    # typing on a box with no keyboard attached.
    openssh.authorizedKeys.keys = [
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIHTAV1WMtmBZ3PMicT0QFN78AUU5eEZuzam2tu136yeZ"
    ];
  };

  # The only tool list this host adds itself; everything else comes from
  # ./packages.nix, which mirrors grandpa's server set.
  environment.systemPackages = with pkgs; [
    iw
  ];
}
