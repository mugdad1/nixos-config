{
  pkgs,
  username,
  ...
}: {
  programs.git = {
    enable = true;

    settings = {
      user = {
        name = username;
        email = "mugdad02@tutamail.com";
      };

      init.defaultBranch = "main";
      merge.conflictstyle = "diff3";
      diff.colorMoved = "default";
      pull.ff = "only";

      url = {
        # SSH only for your own repos; everything else (e.g. lazy.nvim
        # cloning plugins) stays HTTPS so it works without SSH keys/port 22.
        "git@github.com:mugdad1/".insteadOf = [
          "gh:mugdad1/"
          "https://github.com/mugdad1/"
        ];
      };

      core.excludesFile = "~/.config/git/.gitignore";
    };
  };

  programs.delta = {
    enable = true;
    enableGitIntegration = true;

    options = {
      line-numbers = true;
      side-by-side = true;
      diff-so-fancy = true;
      navigate = true;
    };
  };

  home.packages = with pkgs; [gh];

  xdg.configFile."git/.gitignore".text = ''
    .vscode
    .direnv
  '';

  programs.zsh.shellAliases = {
    gs = "git status";
    gcl = "git clone";
    gd = "git diff";

    ga = "git add";
    gaa = "git add --all";

    gc = "git commit";
    gcm = "git commit -m";

    gpl = "git pull";
    gplo = "git pull origin";
    gfa = "git fetch --all --prune --tags";

    gps = "git push";
    gpso = "git push origin";
    gpst = "git push --tags";
    gtag = "git tag -ma";

    gm = "git merge";
    gb = "git branch";
    gch = "git checkout";
    gchb = "git checkout -b";
    gsw = "git switch";
    gswc = "git switch -c";

    grb = "git rebase";
    gcp = "git cherry-pick";

    gst = "git stash";
    gss = "git stash pop";
    gwt = "git worktree";
    gwth = "git worktree add";
    gwtl = "git worktree list";
    gwtr = "git worktree remove";

    glg = "git log --oneline --decorate";
    glog = "git log --oneline --decorate --graph";
    glol = "git log --graph --pretty='%Cred%h%Creset -%C(auto)%d%Creset %s %Cgreen(%ar) %C(bold blue)<%an>%Creset'";
    glola = "git log --graph --pretty='%Cred%h%Creset -%C(auto)%d%Creset %s %Cgreen(%ar) %C(bold blue)<%an>%Creset' --all";
    glols = "git log --graph --pretty='%Cred%h%Creset -%C(auto)%d%Creset %s %Cgreen(%ar) %C(bold blue)<%an>%Creset' --stat";
  };
}
