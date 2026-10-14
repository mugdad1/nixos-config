# Auto-import every module under a directory, RECURSIVELY (since 2026-10-14,
# when modules/home grew subdirectories — before that it only ever saw one
# level, which is why every module used to sit flat).
# Usage: scanPaths ./modules/core
_: {
  scanPaths = path: let
    # Rules, applied to each entry of `path`, in order:
    #   1. a subdirectory that has its own default.nix is imported as a whole
    #      directory (NixOS resolves it to that default.nix, and that file owns
    #      its siblings from there) — no double-import of its children;
    #   2. any other subdirectory is recursed into;
    #   3. a *.nix file other than default.nix is imported;
    #   4. anything else (lua, css, rasi, toml, images …) is ignored.
    # default.nix is skipped at every level: the file that CALLS scanPaths is
    # the aggregator, so importing it again would import the scanner's own
    # caller.
    #
    # Hosts do NOT use this — see the loud comment in
    # hosts/thinkcentre/default.nix: mkHost passes `./hosts/${host}`, and a
    # directory module resolves to its default.nix only. That is deliberate
    # (a host's .sh / data files must never be swept in), so the host keeps an
    # explicit `imports` list while the shared module dirs stay zero-maintenance.
    scan = dir: let
      entries = builtins.readDir dir;
      names = builtins.sort (a: b: a < b) (builtins.attrNames entries);
      handle = name: let
        p = dir + "/${name}";
        kind = entries.${name};
      in
        if kind == "directory"
        then
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
