{pkgs, lib, host, ...}: {
  nix = {
    settings = {
      auto-optimise-store = true;
      builders-use-substitutes = true;
      download-buffer-size = 524288000;
      experimental-features = [
        "nix-command"
        "flakes"
      ];
      max-jobs = "auto";
      substituters = [
        "https://nix-community.cachix.org"
        "https://hyprland.cachix.org"
        "https://ghostty.cachix.org"
      ];
      trusted-public-keys = [
        "nix-community.cachix.org-1:mB9FSh9qf2dCimDSUo8Zy7bkq5CX+/rkCWyvRCYg3Fs="
        "hyprland.cachix.org-1:a7pgxzMz7+chwVL3/pzj6jIBMioiJM7ypFP8PwtkuGc="
        "ghostty.cachix.org-1:QB389yTa6gTyneehvqG58y0WnHjQOqgnA+wBnpWWxns="
      ];
    };

    # gc handled by nh (programs.nh.clean)
    optimise = {
      automatic = true;
      dates = ["03:00"];
    };
  };

  environment.systemPackages = with pkgs; [
    git
  ];

  time.timeZone = "Asia/Riyadh";
  i18n.defaultLocale = "en_US.UTF-8";
  nixpkgs.config = lib.mkMerge [
    { allowUnfree = true; }
    (lib.mkIf (host == "rog") { android_sdk.accept_license = true; })
  ];
  system.stateVersion = "26.05";
}
