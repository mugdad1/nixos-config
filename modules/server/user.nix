# Server user: same mugdad, fish login shell, SSH key auth only.
# Deliberately NOT modules/core/user.nix (that pulls the full desktop home).
# Paste the T480s public key below before first remote deploy (see also
# modules/server/openssh.nix for the one-time LAN bootstrap).
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
      imports = [./home];
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
    extraGroups = ["wheel"];
    shell = pkgs.fish;
    openssh.authorizedKeys.keys = [
      # "ssh-ed25519 AAAA... mugdad@t480s"
    ];
  };
  nix.settings.allowed-users = [username];
}