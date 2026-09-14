# Slim server home: fish + starship + git, zero GUI apps or prompt niceties.
# Reuses the shared git module (git + delta + gh + 34 aliases).
{
  pkgs,
  ...
}: {
  imports = [
    ../../home/git.nix
  ];

  home.packages = [
    (pkgs.writeShellScriptBin "mcli" (builtins.readFile ./../../../scripts/mcli.sh))
  ];

  programs.fish.enable = true;

  programs.starship = {
    enable = true;
    enableFishIntegration = true;
  };

  home.sessionVariables = {
    EDITOR = "vim";
    VISUAL = "vim";
  };
}
