# Grandpa's custom desktop — Intel i3 2nd gen (Sandy Bridge), 6–8 GiB RAM, a
# GeForce GT 210, a single spinning HDD, UEFI. Headless: it is a server / CLI
# box, not a workstation, so it imports modules/core only and never
# modules/desktop.
#
# THE GT 210 (why there is no driver line anywhere in this host): it is a 2009
# Tesla-era card (GT218) whose only NVIDIA driver was the 340.x legacy branch,
# and that branch no longer exists in nixpkgs — nvidiaLegacy340/390 are gone
# (checked against this flake's nixpkgs 2026-10-16). It does not matter: a
# headless box wants no GPU driver at all, so nouveau/nvidia are blacklisted and
# the card sits idle. If a screen is ever wanted, the fix is a cheap GT 710/1030,
# never the dead 340 blob.
#
# ⚠️ NOT YET ON THE HARDWARE: ./hardware-configuration.nix is a PLACEHOLDER.
# On install day, on the box, run
#   sudo nixos-generate-config --show-hardware-config
# and replace it wholesale (never hand-edit the generated one).
#
# WHAT IT IS (his word, 2026-10-16): a **lightweight server** — headless, and
# that part is now a decision, not a placeholder. Which services it runs is
# still open: nothing service-specific (docker, backup, WhatsApp, blocky
# upstream tweaks beyond the shared pair) is pre-wired. Add it here when a
# service is actually chosen. Until install day the box does not exist yet —
# see the hardware warning above.
{...}: {
  imports = [
    ./hardware-configuration.nix
    ../../modules/core
    # Headless: deliberately NOT ../../modules/desktop — the same omission that
    # makes thinkcentre headless, since core stopped dragging the desktop in on
    # 2026-10-12.

    # MUST BE LISTED EXPLICITLY. mkHost passes ./hosts/${host} as its module, and
    # a NixOS module that is a *directory* resolves to that directory's
    # default.nix ONLY — it does not sweep up sibling .nix files. hosts/thinkcentre
    # learned this the expensive way (see the long warning in its default.nix).
    ./packages.nix
    ./overrides.nix
  ];

  # The ESP lives at /boot (systemd-boot writes there; NixOS's default is already
  # /boot, but keep it explicit so a regenerated hardware-configuration.nix that
  # mounts the ESP elsewhere cannot silently write to a non-ESP directory and
  # boot the old loader — the exact failure documented in
  # hosts/thinkcentre/default.nix).
  boot.loader.efi.efiSysMountPoint = "/boot";

  # No display is ever attached. Blacklist the whole NVIDIA stack so neither
  # nouveau nor the blob claims the text console or costs a few hundred MB of
  # 6–8 GiB for nothing; the console still comes up on efifb.
  boot.blacklistedKernelModules = [
    "nouveau"
    "nvidia"
    "nvidia_drm"
    "nvidiafb"
  ];

  # Time, same posture as thinkcentre: a literal-IPv4 NTP list, so the clock can
  # be fixed even when DNS is down (the full deadlock reasoning lives in
  # hosts/thinkcentre/default.nix). Nothing here assumes the CMOS cell is missing
  # — it is simply never worse than the pool hostname.
  services.timesyncd.enable = true;
  networking.timeServers = [
    "162.159.200.1" # time.cloudflare.com
    "216.239.35.0" # time.google.com
    "216.239.35.4"
  ];

  # zram, not a swap partition: the disk is a slow spinning HDD and RAM is only
  # 6–8 GiB, so compressed RAM swap buys far more than a swap file on the
  # platter. Same shape as thinkcentre.
  zramSwap = {
    enable = true;
    algorithm = "lz4";
    memoryPercent = 35;
    priority = 100;
  };

  # hostname comes from core/network.nix: networking.hostName = host = "grandpa".
}
