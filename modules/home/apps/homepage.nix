{pkgs, ...}: let
  # One declaration, one render: lib/server-index.nix holds the fleet's
  # service list and produces the HTML. This module only ships it.
  index = pkgs.writeText "server-index.html" (import ../../../lib/server-index.nix {});

  # SERVE POINT MOVED 2026-10-22: the page is no longer pushed anywhere — it is
  # served DECLARATIVELY by nginx on grandpa (hosts/grandpa/default.nix, the
  # index virtualHost whose root is the same `import lib/server-index.nix`).
  # So this script is now just a pointer; its old body is kept commented below
  # as the record of the rsync-into-a-docroot era.
  #
  # IP + PATH, 2026-10-15. The tailnet address moved 100.124.75.45 ->
  # 100.88.29.31 (the ThinkCentre was reinstalled; tailscale re-registered it
  # under a new IP). Every hard-coded copy of the old one in this flake had to
  # follow, or push-server-index ships to a dead address and the curl check
  # below reports "links served: 0". The remote path was also capital-P
  # `Projects/` — the server's restored tree is lowercase `projects/`, and
  # rsync would have created a SECOND directory beside the real one, leaving
  # Caddy serving the old file from the path it actually bind-mounts.
  deploy = pkgs.writeShellScriptBin "push-server-index" ''
    set -eu
    echo "push-server-index: retired 2026-10-22 — the index is served by nginx"
    echo "on grandpa (http://100.106.116.60/), declared in"
    echo "hosts/grandpa/default.nix, so a rebuild is the publish."
    echo "Local copy: ~/.local/share/mugdad/server-index.html"
    exit 1
    # rsync -L --inplace --verbose ${index} mugdad@HOST:PATH/index.html
    # curl -s --max-time 8 http://HOST/ | grep -c "href=" | sed 's/^/links served: /'
  '';
in {
  # The same page, readable locally too — useful when the tailnet is down and
  # the box is unreachable, and it is what push-server-index ships.
  home.file.".local/share/mugdad/server-index.html".text =
    import ../../../lib/server-index.nix {};

  home.packages = [deploy];
}
