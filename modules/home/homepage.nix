{
  pkgs,
  ...
}: let
  # One declaration, one render: lib/server-index.nix holds the ThinkCentre's
  # service list and produces the HTML. This module only ships it.
  index = pkgs.writeText "server-index.html" (import ../../lib/server-index.nix {});

  # scp would also do it, but rsync creates a temp file and renames it over the
  # target, which swaps the INODE — and Caddy has this file bind-mounted
  # read-only at /usr/share/caddy/index.html, so a renamed inode leaves the
  # container serving the old bytes until it restarts. --inplace writes through
  # the existing inode instead, which is the whole trick here.
  deploy = pkgs.writeShellScriptBin "push-server-index" ''
    set -eu
    rsync -L --inplace --verbose ${index} void@100.97.91.119:Projects/servers/caddy/index.html
    echo "--- verifying the container serves the new bytes:"
    curl -s --max-time 8 http://100.97.91.119/ | grep -c "href=" | sed 's/^/links served: /'
  '';
in {
  # The same page, readable locally too — useful when the tailnet is down and
  # the box is unreachable, and it is what push-server-index ships.
  home.file.".local/share/mugdad/server-index.html".text =
    import ../../lib/server-index.nix {};

  home.packages = [deploy];
}
