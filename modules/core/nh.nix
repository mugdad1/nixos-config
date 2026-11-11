{pkgs, ...}: {
  programs.nh = {
    enable = true;
    clean = {
      enable = true;
      # Keep a two-week-old known-good system, and never fewer than 10.
      extraArgs = "--keep-since 14d --keep 10";
    };
  };

  environment.systemPackages = with pkgs; [
    nix-output-monitor
    nvd
  ];
}
