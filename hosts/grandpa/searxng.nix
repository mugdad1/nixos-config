# SearXNG — the house search engine, declared natively (no docker). Browsers
# and the `web-search` helper point at :8888.
{config, ...}: {
  services.searx = {
    enable = true;

    # Renders $SEARX_SECRET_KEY during searx-init; systemd reads it as PID 1.
    environmentFile = config.sops.templates."searxng.env".path;

    settings = {
      use_default_settings = true;

      server = {
        port = 8888;
        bind_address = "0.0.0.0";
        base_url = "http://100.106.116.60:8888/";
        secret_key = "$SEARX_SECRET_KEY";
        limiter = false;
        image_proxy = true;
      };

      # html for people, json for scripts hitting /search.
      search.formats = ["html" "json"];

      ui.static_use_hash = true;
    };
  };

  networking.firewall.interfaces."tailscale0".allowedTCPPorts = [8888];
}
