# 12GB RAM is thin for postgres + Immich ML, so compress swap in zram (faster
# and gentler on the SSD than the disk swap) and let oomd kill runaway workers
# before the kernel OOM locks up the box.
{lib, ...}: {
  zramSwap = {
    enable = true;
    memoryPercent = 50;
  };

  # oomd is recommended alongside zram: once the compressed swap fills, memory
  # pressure spikes and the kernel OOM killer can be too slow.
  systemd.oomd.enable = true;

  # Push pressure into zram (priority 5) ahead of the disk swap partition.
  # system.nix sets 10 for the desktop; a swap-happy server beats an OOM.
  boot.kernel.sysctl."vm.swappiness" = lib.mkForce 140;
}