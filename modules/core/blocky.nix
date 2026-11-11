# Blocky owns 127.0.0.1:53 and races every upstream in a group, taking the
# first answer. The two filtered profiles are queried over DoH (443) because
# the university's firewall drops DoT/DoQ; the laptops also ask grandpa over
# the tailnet as a path that survives even when public DoH is blocked.
{
  host,
  lib,
  ...
}: let
  # grandpa must not ask itself.
  asked = host != "grandpa";
in {
  services.blocky = {
    enable = true;
    settings = {
      ports.dns = "127.0.0.1:53";

      upstreams = {
        init.strategy = "fast";
        groups.default =
          [
            "https://dns.nextdns.io/cbf8aa"
            "https://2b44bd66.d.adguard-dns.com/dns-query"
          ]
          ++ lib.optionals asked [
            "tcp+udp:100.106.116.60"
          ];
      };

      # Plain DNS on purpose: these only resolve the DoH hostnames above and
      # need no certificate (DoH-by-IP fails with "no IP SANs").
      bootstrapDns =
        [
          {upstream = "tcp+udp:9.9.9.11";}
          {upstream = "tcp+udp:94.140.14.14";}
        ]
        ++ lib.optionals asked [
          {upstream = "tcp+udp:100.106.116.60";}
        ];

      caching = {
        minTime = "5m";
        maxTime = "30m";
        prefetching = true;
      };

      # Forward only the tailnet suffix to MagicDNS; everything else stays on
      # the default upstreams.
      conditional = {
        fallbackUpstream = false;
        mapping = {
          "tailbc99bb.ts.net" = "100.100.100.100";
        };
      };
    };
  };
}
