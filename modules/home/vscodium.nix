{pkgs, ...}: {
  programs.vscodium = {
    enable = true;
    # FHS wrapper keeps runtime compatibility (e.g. extension host binaries)
    package = pkgs.vscodium.fhs;
    # extensions fully managed by nix: nothing installable/updatable in GUI
    mutableExtensionsDir = false;

    profiles.default = {
      extensions = with pkgs.vscode-extensions; [
        ## Web dev
        bmewburn.vscode-intelephense-client # PHP intellisense
        esbenp.prettier-vscode # web formatting
        ritwickdey.liveserver # local dev server
        formulahendry.auto-rename-tag
        formulahendry.auto-close-tag
        bradlc.vscode-tailwindcss

        ## Shell / scripting
        mads-hartmann.bash-ide-vscode
        timonwong.shellcheck

        ## C (OS course) - cpptools is not on Open VSX, clangd + lldb are
        llvm-vs-code-extensions.vscode-clangd
        vadimcn.vscode-lldb

        ## QoL
        usernamehw.errorlens
        eamodio.gitlens
        jdinhlife.gruvbox
      ];

      userSettings = {
        "workbench.colorTheme" = "Gruvbox Dark Medium";
        "editor.fontFamily" = "'Iosevka Nerd Font', monospace";
        "editor.fontSize" = 14;
        "editor.fontLigatures" = true;
        "editor.formatOnSave" = true;
        "files.autoSave" = "afterDelay";
        "extensions.autoUpdate" = false;
        "extensions.autoCheckUpdates" = false;
        "update.mode" = "none";
        "telemetry.telemetryLevel" = "off";
        "terminal.integrated.defaultProfile.linux" = "zsh";
        "[php]"."editor.defaultFormatter" = "bmewburn.vscode-intelephense-client";
      };
    };
  };
}
