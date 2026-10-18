{pkgs, ...}: {
  programs.nh = {
    enable = true;
    clean = {
      enable = true;
      # RETENTION, deepened 2026-10-18. nh-clean was NOT missing - it has run on
      # all three hosts since this file existed, and what was actually wrong was
      # what it kept. `--keep-since 1d --keep 1` leaves today plus one
      # generation, so by the next morning the rollback you want after a bad
      # update (`nixos-rebuild --rollback`, or an older entry in the
      # systemd-boot menu that boot.configurationLimit=10 promises) is gone, and
      # the store GC that removes it is the same run. On a server rebuilt rarely
      # that is no rollback at all after day two.
      #
      # 14 days AND at least 10 generations: `--keep 10` is the real safety net
      # (it survives any amount of time), `--keep-since 14d` keeps a two-week
      # old known-good system around on hosts that rebuild in bursts. Bounded,
      # not open-ended - the laptop's store is 37 GB with weeks of generations
      # in it, the thinkcentre's is 11 GB.
      extraArgs = "--keep-since 14d --keep 10";
    };
  };

  environment.systemPackages = with pkgs; [
    nix-output-monitor
    nvd
  ];
}
