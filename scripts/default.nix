{pkgs, ...}: let
  scriptDir = ./.;
  scriptEntries = builtins.readDir scriptDir;
  regularFiles = builtins.filter (name: scriptEntries.${name} == "regular") (builtins.attrNames scriptEntries);
  shellScripts = builtins.filter (name: builtins.match ".*\\.sh$" name != null) regularFiles;

  mkScript = name: let
    base = pkgs.lib.removeSuffix ".sh" name;
  in {
    name = base;
    value = pkgs.writeScriptBin base (
      builtins.readFile (scriptDir + "/${name}")
    );
  };

  scriptsSet = builtins.listToAttrs (map mkScript shellScripts);
in {
  home.packages = builtins.attrValues scriptsSet;
}
