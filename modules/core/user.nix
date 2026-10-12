{
  pkgs,
  lib,
  inputs,
  username,
  host,
  variables,
  ...
}: {
  imports = [inputs.home-manager.nixosModules.home-manager];
  home-manager = {
    useUserPackages = true;
    useGlobalPkgs = true;
    extraSpecialArgs = {inherit inputs username host variables;};
    users.${username} = {
      # ../home is the DESKTOP's home stack (sway, waybar, rofi, browser …) and
      # it hard-reads variables.browser/terminal/launcher — evaluate it on a
      # headless host and you get "attribute 'browser' missing". Gating on the
      # variables themselves rather than a hostname means a host gets the
      # desktop home stack exactly when its variables declare a desktop, with
      # no host list to maintain. The ThinkCentre declares none.
      imports = lib.optionals (variables ? browser) [../home];
      home.username = username;
      home.homeDirectory = "/home/${username}";
      home.stateVersion = "26.05";
      programs.home-manager.enable = true;
    };
    backupFileExtension = "hm-backup";
  };

  # Note: no adb udev setup needed — systemd 258 handles device
  # access automatically; android-tools is already in system packages.
  users.users.${username} = {
    isNormalUser = true;
    description = username;
    extraGroups = [
      "networkmanager"
      "wheel"
      "input"
      "video"
      "render"
    ];
    shell = pkgs.fish;
  };
  nix.settings.allowed-users = [username];
}
