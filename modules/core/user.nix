{
  pkgs,
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
      imports = [../home];
      home.username = username;
      home.homeDirectory = "/home/${username}";
      home.stateVersion = "26.05";
      programs.home-manager.enable = true;
    };
    backupFileExtension = "hm-backup";
  };

  # Android flashing: udev rules + adbusers group so adb/fastboot
  # work as non-root (needed for the OnePlus 7T Pro on Tuesday)
  programs.adb.enable = true;

  users.users.${username} = {
    isNormalUser = true;
    description = username;
    extraGroups = [
      "networkmanager"
      "wheel"
      "input"
      "video"
      "render"
      "adbusers"
    ];
    shell = pkgs.zsh;
  };
  nix.settings.allowed-users = [username];
}
