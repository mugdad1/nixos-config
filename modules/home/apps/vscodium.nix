{
  pkgs,
  lib,
  ...
}: let
  # Seeded once into ~/.config/VSCodium/User/settings.json; afterwards it is a
  # normal editable file.
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
      "terminal.integrated.defaultProfile.linux" = "fish";
    }
  );
in {
  programs.vscodium = {
    enable = true;
    package = pkgs.vscodium.fhs;
    mutableExtensionsDir = false;

    profiles.default = {
      extensions = with pkgs.vscode-extensions; [
        ## Web dev
        bmewburn.vscode-intelephense-client
        esbenp.prettier-vscode
        ritwickdey.liveserver
        formulahendry.auto-rename-tag
        formulahendry.auto-close-tag
        bradlc.vscode-tailwindcss

        ## Shell / scripting
        mads-hartmann.bash-ide-vscode
        timonwong.shellcheck

        ## C
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
      install -m 644 ${defaultSettings} "$S"
    fi
  '';
}
