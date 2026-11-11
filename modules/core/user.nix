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
      # The desktop home stack requires variables.browser/terminal/launcher, so
      # a headless host simply does not declare them.
      imports = lib.optionals (variables ? browser) [../home];
      home.username = username;
      home.homeDirectory = "/home/${username}";
      home.stateVersion = "26.05";
      programs.home-manager.enable = true;
    };
    backupFileExtension = "hm-backup";
  };

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
