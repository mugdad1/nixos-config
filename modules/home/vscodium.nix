{
  pkgs,
  lib,
  ...
}: let
  # Seeded ONCE into ~/.config/VSCodium/User/settings.json (only if the file
  # doesn't exist yet). Afterwards it's a normal editable file - GUI changes
  # survive rebuilds.
  defaultSettings = pkgs.writeText "codium-default-settings.json" (
    builtins.toJSON {
      "security.workspace.trust.enabled" = false;
      "extensions.autoUpdate" = false;
      "extensions.autoCheckUpdates" = false;
      "update.mode" = "none";
      "telemetry.telemetryLevel" = "off";
      "workbench.colorTheme" = "Gruvbox Dark Medium";
      "editor.fontFamily" = "'Iosevka Nerd Font', monospace";
      "editor.fontSize" = 14;
      "editor.formatOnSave" = true;
      "files.autoSave" = "afterDelay";
      "terminal.integrated.defaultProfile.linux" = "zsh";
    }
  );
in {
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
        jdinhlife.gruvbox
      ];
    };
  };

  home.activation.seedVSCodiumSettings = lib.hm.dag.entryAfter ["writeBoundary"] ''
    S="$HOME/.config/VSCodium/User/settings.json"
    if [ ! -f "$S" ]; then
      mkdir -p "$(dirname "$S")"
      # install instead of cp so it doesn't inherit the store path's
      # read-only mode
      install -m 644 ${defaultSettings} "$S"
    fi
  '';
}
