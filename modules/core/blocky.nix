{
  host,
  lib,
  ...
}:
# Blocky owns 127.0.0.1:53 as the local resolver and races every upstream of a
# group in parallel, taking the first answer. That is the whole design: no
# per-network switching and no "which wifi am I on" logic.
#
# Transport rewritten 2026-10-26 (wiki decisions row 222). The university's
# Fortinet drops udp/53, tcp/53 AND tcp/853 to every external resolver, so the
# old NextDNS DoT + AdGuard DoQ pair worked at home and was stone dead on
# campus. The two work resolvers that used to paper over that gap
# (192.168.44.187/.188) are the university's own and are deliberately NOT
# listed — his words: "these dnses are for uni". What is left:
#
#   1. DoH on 443 to the same two filtered profiles, so the ad/tracker/malware
#      blocking is unchanged: NextDNS keeps its profile id in the path, AdGuard
#      keeps its device id in the hostname. Verified on 2026-10-26 through a
#      throwaway blocky: doubleclick.net and googleadservices.com came back
#      0.0.0.0, example.com resolved normally.
#   2. Plain DNS to grandpa over the tailnet. WireGuard traffic matches no DPI
#      rule, and grandpa races the same two profiles from home, so the answers
#      are the same — including the blocking (verified: doubleclick.net ->
#      0.0.0.0 through 100.106.116.60). This is the path that survives even if
#      every public DoH endpoint is blackholed, which is why it is an upstream
#      and not just a bootstrap entry.
#   3. Quad9 DoH as a neutral third opinion for when the filtered pair is slow.
#      It was removed on 2026-10-12 because a `strict` strategy stalled behind
#      dead upstreams; with `fast` it cannot stall anything.
#
# grandpa is the server being asked, so it must not ask itself: entry 2 is
# gated on host. Its own blocky already binds 0.0.0.0:53 and its firewall
# accepts :53 on tailscale0 only (hosts/grandpa/overrides.nix).
let
  # Only the two laptops tunnel home for DNS. grandpa keeps the encrypted pair
  # it has always raced, with no tailnet hop.
  asked = host != "grandpa";
in {
  services.blocky = {
    enable = true;
    settings = {
      ports.dns = "127.0.0.1:53";

      upstreams = {
        init.strategy = "fast"; # don't block startup on upstream probes
        groups.default =
          [
            # Both filtered profiles, now over DoH (443) instead of DoT (853)
            # and DoQ. Same accounts, same blocklists, transport that campus
            # does not drop on sight.
            "https://dns.nextdns.io/cbf8aa"
            "https://2b44bd66.d.adguard-dns.com/dns-query"
            # Quad9 used to sit here as a "neutral third opinion". It was
            # removed within hours of the switch: blocky races every upstream
            # in the group and takes the FIRST answer, so an unfiltered
            # resolver in the same group makes ad-blocking a coin flip.
            # Measured: doubleclick.net resolved to a real address because
            # Quad9 won the race. Speed is not worth losing the filtering.
          ]
          ++ lib.optionals asked [
            # The bypass that cannot be filtered: DNS inside WireGuard, answered
            # by grandpa at home with the same profile pair.
            "tcp+udp:100.106.116.60"
          ];
      };

      # Used only to resolve the DoH hostnames above, never for queries. Every
      # entry is an IP-literal DoH endpoint or a plain-DNS address, so bootstrap
      # itself needs no resolver — which matters when the only working resolver
      # is the one being bootstrapped.
      bootstrapDns =
        [
          { upstream = "https://9.9.9.11/dns-query"; } # Quad9, cert has IP SAN
          { upstream = "https://94.140.14.14/dns-query"; } # AdGuard
        ]
        ++ lib.optionals asked [
          { upstream = "tcp+udp:100.106.116.60"; }
        ];

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
