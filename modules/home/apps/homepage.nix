{pkgs, ...}: let
  # One declaration, one render: lib/server-index.nix holds the fleet's
  # service list and produces the HTML. This module only ships it.
  index = pkgs.writeText "server-index.html" (import ../../../lib/server-index.nix {});

  # DEPLOY DISABLED 2026-10-22: the target was the ThinkCentre's Caddy
  # docroot (`mugdad@100.88.29.31:projects/servers/caddy/index.html`) and
  # that box was returned to its owner — the address has no machine behind
  # it, and grandpa runs no Caddy. The script body below is kept as the
  # record of how the page shipped (rsync --inplace, not scp: a rename swaps
  # the INODE and a bind-mounted docroot keeps serving the old bytes until
  # the container restarts; --inplace writes through the existing inode).
  # When a web host for the index is decided, point the rsync at it and the
  # curl check at the same address, then uncomment.
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
    echo "push-server-index: no host for the index since the ThinkCentre was"
    echo "returned 2026-10-22 — the rendered page is at"
    echo "~/.local/share/mugdad/server-index.html. See homepage.nix."
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
