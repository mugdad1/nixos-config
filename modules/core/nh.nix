{...}: {
  programs.nh = {
    enable = true;
    clean = {
      enable = true;
      extraArgs = "--keep-since 1d --keep 1";
    };
    flake = builtins.toString ../../.;
  };
}
