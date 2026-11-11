{pkgs, ...}: let
  # The page is also rendered locally, for when the tailnet is down.
  index = pkgs.writeText "server-index.html" (import ../../../lib/server-index.nix {});

  # Retired rsync shipper; nginx on grandpa serves the page declaratively now.
  deploy = pkgs.writeShellScriptBin "push-server-index" ''
    set -eu
    echo "push-server-index: retired 2026-10-22 — the index is served by nginx"
    echo "on grandpa (http://100.106.116.60/), declared in"
    echo "hosts/grandpa/default.nix, so a rebuild is the publish."
    echo "Local copy: ~/.local/share/mugdad/server-index.html"
    exit 1
  '';
in {
  home.file.".local/share/mugdad/server-index.html".source = index;

  home.packages = [deploy];
}
