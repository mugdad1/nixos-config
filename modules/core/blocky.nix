{
  lib,
  ...
}: {
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
          "quic:dns.adguard-dns.com" # DoQ
          "tcp-tls:dns.adguard-dns.com" # DoT
          "https://dns.adguard-dns.com/dns-query" # DoH
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
    };
  };
}
