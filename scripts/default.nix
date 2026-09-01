{
  pkgs,
  ...
}: let
  scriptDir = ./.;
  scriptEntries = builtins.readDir scriptDir;
  regularFiles = builtins.filter (name: scriptEntries.${name} == "regular") (builtins.attrNames scriptEntries);
  shellScripts = builtins.filter (name: builtins.match ".*\\.sh$" name != null) regularFiles;

  mkScript = name: {
    name = pkgs.lib.replaceStrings [".sh"] [""] name;
    value = pkgs.writeScriptBin (pkgs.lib.replaceStrings [".sh"] [""] name) (
      builtins.readFile (scriptDir + "/${name}")
    );
  };

  scriptsSet = builtins.listToAttrs (map mkScript shellScripts);
in {
  home.packages = builtins.attrValues scriptsSet;
}
