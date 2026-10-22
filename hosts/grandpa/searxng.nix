# ─── SearXNG — declared NIX-NATIVE 2026-10-22 ───────────────────────────────
# His word: "Declare it inside grandpa". Until today this was the last service
# on the fleet that existed ONLY as ~/projects/servers/searxng/docker-compose.yml
# on the ThinkCentre — no Nix declaration anywhere — so it would have died with
# the box being returned. It is the house's search engine: browser.nix points
# the default search bar at it, and the web-search rule routes every lookup
# through it.
#
# WHAT THIS REPLACES, and what deliberately does not move:
#   compose   stays on the ThinkCentre untouched — comment-out-don't-delete,
#             and it ships back with the box anyway. The docker engine, the
#             redis container (never referenced by settings.yml — dead weight
#             the compose inherited from an example) and ./data/ stay put as
#             well; nothing is deleted anywhere.
#   data/     superseded, not migrated: settings.yml comes from Nix below, and
#             the session secret inside it moved to secrets/fleet.sops.yaml
#             (key `searx/secret_key`, added the same day — ciphertext only).
#   base_url  was http://100.97.91.119:8888/ — a tailnet IP this box no longer
#             holds. The rule is always tailnet addresses, so it becomes
#             100.106.116.60, THIS box, written here rather than discovered.
#
# MODULE SHAPE (nixpkgs' services.searx is the SearXNG module — package
# defaults to searxng, docs point at searxng.org):
#   configureUwsgi = false (default) -> searxng's own built-in HTTP server,
#   exactly what the container ran. Not nginx/uwsgi: this is one household on
#   a tailnet, and the module's own note says that mode is unnecessary for
#   LAN/local use. No redisCreateLocally because `server.limiter = false`,
#   carried over from the compose settings — the limiter is what redis exists
#   for, and it was never enabled on the old box.
#
# PORT 8888, not the module's 8080: the address in every bookmark, in
# browser.nix and in the web-search rule is :8888 — keeping it means those
# keep working with only the host part changing.
#
# FIREWALL: tailscale0 only. The compose published 8888 on every interface
# (docker's default), but every consumer — his laptop, his phone, the agents'
# search — reaches it over the tailnet, and an open search box on the LAN
# answers questions nobody here asked. Bind is 0.0.0.0 for the same reason
# blocky binds 0.0.0.0: sv-watch health-checks 127.0.0.1:8888, and loopback
# has to answer for that sweep to mean anything. LAN can come back the day
# something on the LAN needs it — one line, same as HA's 8123.
{config, ...}: {
  services.searx = {
    enable = true;
    # package is the module's default (pkgs.searxng) — stated for the reader,
    # not overridden.

    # $SEARX_SECRET_KEY for the module's envsubst pass during searx-init.
    # systemd reads this as PID 1 before dropping to the searx user, so the
    # 0400 root-owned render is fine where a hand-made file would not be.
    environmentFile = config.sops.templates."searxng.env".path;

    settings = {
      # The compose's settings.yml said `use_default_settings: true`; the
      # module mkDefaults it too, kept explicit to match the file this came from.
      use_default_settings = true;

      server = {
        port = 8888;
        bind_address = "0.0.0.0"; # loopback for sv-watch, LAN closed below
        base_url = "http://100.106.116.60:8888/"; # tailnet, always
        secret_key = "$SEARX_SECRET_KEY"; # sops placeholder, never in Nix
        limiter = false; # as on the old box — and no redis because of it
        image_proxy = true; # thumbnails proxied through here, not leaked out
      };

      # html for people, json for anything scripted against /search — both were
      # enabled in the compose settings and both are used.
      search.formats = ["html" "json"];

      ui.static_use_hash = true;
    };
  };

  # tailscale0 only — see the header. 8888/tcp alone; DNS-port pattern above
  # in overrides.nix is unrelated.
  networking.firewall.interfaces."tailscale0".allowedTCPPorts = [8888];
}
