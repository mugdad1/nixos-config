_:
# Auto-import all .nix files in a directory except default.nix
# Usage: scanPaths ./modules/core
{
  scanPaths = path:
    let
      files = builtins.attrNames (builtins.readDir path);
      nixFiles = builtins.filter (f: (builtins.match ".*\\.nix" f) != null && f != "default.nix") files;
    in map (f: path + "/${f}") nixFiles;
}
