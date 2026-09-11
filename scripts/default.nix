{pkgs, variables, ...}: let
  scriptDir = ./.;
  scriptEntries = builtins.readDir scriptDir;
  regularFiles = builtins.filter (name: scriptEntries.${name} == "regular") (builtins.attrNames scriptEntries);
  shellScripts = builtins.filter (name:
    builtins.match ".*\\.sh$" name != null
    && name != "toggle-display.sh")
  regularFiles;

  mkScript = name: let
    base = pkgs.lib.removeSuffix ".sh" name;
  in {
    name = base;
    value = pkgs.writeScriptBin base (
      builtins.readFile (scriptDir + "/${name}")
    );
  };

  scriptsSet = builtins.listToAttrs (map mkScript shellScripts);

  displays = variables.displays;

  toggleDisplay = pkgs.writeScriptBin "toggle-display" ''
    #!/usr/bin/env bash
    set -euo pipefail

    PRIMARY="${displays.primary}"

    if hyprctl monitors | grep -q "^Monitor $PRIMARY"; then
        hyprctl keyword monitor "$PRIMARY,disable"
    else
        hyprctl keyword monitor "$PRIMARY,${displays.resolution}@${toString displays.refreshRate},0x0,${builtins.toJSON displays.scale}"
    fi
  '';
in {
  home.packages = builtins.attrValues scriptsSet ++ [
    toggleDisplay
    pkgs.inxi
  ];
}
