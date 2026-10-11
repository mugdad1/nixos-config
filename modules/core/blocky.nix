_: {
  # Blocky owns 127.0.0.1:53 as local resolver — the same 4 upstreams as the
  # AGH on thinkcentre, raced in parallel (blocky races all upstreams of a
  # group and takes the first answer):
  #   at home the NextDNS/AdGuard encrypted upstreams answer, the unreachable
  #   work resolvers simply lose the race; at work 192.168.44.187/.188 answer
  #   and the blocked encrypted upstreams are ignored. No per-network switching.
  services.blocky = {
    enable = true;
    settings = {
      ports.dns = "127.0.0.1:53";

      upstreams = {
        init.strategy = "fast"; # don't block startup on upstream probes
        # blocky (0.33, the same build the ThinkCentre runs) rejects the bare
        # tls:// and quic:// forms — tls:// dies on the empty port. Native form
        # only: tcp-tls:host:port / quic:host. Proven on the server 2026-10-11.
        groups.default = [
          "tcp-tls:cbf8aa.dns.nextdns.io:853" # NextDNS, DoT
          "quic:2b44bd66.d.adguard-dns.com" # AdGuard DNS, DoQ
          "192.168.44.187" # work resolver — only reachable at work
          "192.168.44.188" # work resolver — only reachable at work
        ];
      };

      bootstrapDns = {
        # Resolves the DoT/DoQ upstream hostnames above (a resolver can't ask
        # itself). Used only at bootstrap, never for general queries.
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

      # Tailnet names still resolve, without Tailscale owning DNS: only queries
      # for the tailnet suffix are forwarded to MagicDNS at quad-100. Everything
      # else keeps the default upstreams above. (Same mechanism this repo ran
      # 2026-09, when it was removed along with Tailscale itself.)
      conditional = {
        fallbackUpstream = false;
        mapping = {
          "tailbc99bb.ts.net" = "100.100.100.100";
        };
      };
    };
  };
}
