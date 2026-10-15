{pkgs, ...}: let
  # One declaration, one render: lib/server-index.nix holds the ThinkCentre's
  # service list and produces the HTML. This module only ships it.
  index = pkgs.writeText "server-index.html" (import ../../../lib/server-index.nix {});

  # scp would also do it, but rsync creates a temp file and renames it over the
  # target, which swaps the INODE — and Caddy has this file bind-mounted
  # read-only at /usr/share/caddy/index.html, so a renamed inode leaves the
  # container serving the old bytes until it restarts. --inplace writes through
  # the existing inode instead, which is the whole trick here.
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
    rsync -L --inplace --verbose ${index} mugdad@100.88.29.31:projects/servers/caddy/index.html
    echo "--- verifying the container serves the new bytes:"
    curl -s --max-time 8 http://100.88.29.31/ | grep -c "href=" | sed 's/^/links served: /'
  '';
in {
  # The same page, readable locally too — useful when the tailnet is down and
  # the box is unreachable, and it is what push-server-index ships.
  home.file.".local/share/mugdad/server-index.html".text =
    import ../../../lib/server-index.nix {};

  home.packages = [deploy];
}
