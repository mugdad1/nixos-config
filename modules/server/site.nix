# Private static site (tailnet-only).
# Serves a static SPA from /srv/site over the tailnet. The source repo is
# private on GitHub; nixos-config stays public, so no site content is
# committed here — /srv/site is filled by scripts/site-sync.sh.
# Port 8081 mirrors the local dev server. The firewall opens only port 22,
# so tailscaled's own netfilter rules are the only path in: reachable as
# http://asus:8081 on the tailnet, never from the public internet.
{
  services.nginx = {
    enable = true;

    virtualHosts.site = {
      listen = [
        {
          addr = "0.0.0.0";
          port = 8081;
        }
      ];
      root = "/srv/site";

      # Static SPA (single index.html + query-param routing, no history API
      # fallback needed). No-cache headers replicate the dev server behavior —
      # edits appear instantly, browsers never serve stale JS.
      locations."/" = {
        tryFiles = "$uri $uri/ /index.html";
        extraConfig = ''
          add_header Cache-Control "no-store, no-cache, must-revalidate";
          add_header Pragma "no-cache";
        '';
      };

      extraConfig = ''
        index index.html;
        charset utf-8;
        gzip on;
        gzip_types text/plain text/css application/javascript application/json application/xml image/svg+xml;
      '';
    };
  };

  # /srv/site is owned by mugdad (writable for scripted deploys) and group
  # nginx (so the worker can read files regardless of umask).
  systemd.tmpfiles.rules = [
    "d /srv/site 0755 mugdad nginx - -"
  ];
}