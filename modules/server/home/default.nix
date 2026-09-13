# Slim server home: fish + starship + git, zero GUI apps or prompt niceties.
# Reuses the shared git module (git + delta + gh + 34 aliases).
{...}: {
  imports = [
    ../../home/git.nix
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
