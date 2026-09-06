_: {
  # Blocky owns 127.0.0.1:53 as local resolver. Upstreams are all encrypted
  # transports of dns.adguard-dns.com raced in parallel_best - a stalled QUIC
  # connection can never take resolution down.
  services.blocky = {
    enable = true;
    settings = {
      ports.dns = "127.0.0.1:53";

      upstreams = {
        init.strategy = "fast"; # don't block startup on upstream probes
        groups.default = [
          "quic://2b44bd66.d.adguard-dns.com" # DoQ
          "192.168.44.187"
          "192.168.44.188"
        ];
      };

      bootstrapDns = {
        upstream = "tcp-tls:dns.adguard-dns.com";
        ips = [
          "94.140.14.14"
          "94.140.15.15"
        ];
      };

      caching = {
        minTime = "5m";
        maxTime = "30m";
        prefetching = true;
      };

      # Tailnet names still resolve through Blocky: forward the whole
      # tailnet suffix to Tailscale's MagicDNS at quad-100. Everything
      # else keeps using the encrypted upstreams above. Tailscale itself
      # must NOT own DNS (tailscale set --accept-dns=false, kept as
      # extraUpFlags in tailscale.nix for fresh installs).
      conditional = {
        fallbackUpstream = false;
        mapping = {
          "tailbc99bb.ts.net" = "100.100.100.100";
        };
      };
    };
  };
}
