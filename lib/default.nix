# Recursively import every module under a directory.
# Usage: scanPaths ./modules/core
_: {
  scanPaths = path: let
    scan = dir: let
      entries = builtins.readDir dir;
      names = builtins.sort (a: b: a < b) (builtins.attrNames entries);
      handle = name: let
        p = dir + "/${name}";
        kind = entries.${name};
      in
        if kind == "directory"
        then
          # A directory with its own default.nix owns its children.
          if builtins.pathExists (p + "/default.nix")
          then [p]
          else scan p
        else if kind == "regular" && name != "default.nix" && (builtins.match ".*\\.nix" name) != null
        then [p]
        else [];
    in
      builtins.concatLists (map handle names);
  in
    scan path;
}
