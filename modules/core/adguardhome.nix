{lib, ...}: {
  # AdGuard Home as the local filtering resolver on 127.0.0.1:53.
  #
  # Fully declarative: mutableSettings = false means the yaml under
  # /var/lib/AdGuardHome is regenerated from these settings on every rebuild and
  # anything changed in the web UI is thrown away. schema_version comes from the
  # package, so it tracks the NixOS-shipped release.
  services.adguardhome = {
    enable = true;
    mutableSettings = false;

    # Web UI only. Bound to loopback so the admin panel is not reachable from
    # the LAN or the tailnet (see README: no inbound ports unless a module opens
    # them). The DNS port is set separately, in settings.dns below.
    host = "127.0.0.1";
    port = 3000;

    settings = {
      dns = {
        # Loopback only: this laptop is its own resolver. Nothing on the LAN can
        # use it, and nothing outside can query it.
        bind_hosts = ["127.0.0.1"];
        port = 53;

        # Fire the query at every upstream at once and take the first answer that
        # comes back. This is the whole point: at home the encrypted upstreams
        # answer in a few ms and the unreachable work IP is simply ignored; at
        # work the 192.168.x.x server answers and the encrypted upstreams (which
        # the corporate network drops) never win the race. No health-check
        # state, no "wait for all", no per-network switching needed.
        upstream_mode = "parallel";

        # Upstream pool, raced in parallel. Order is irrelevant under `parallel`.
        #   - AdGuard DNS, encrypted (DoT + DoH), unfiltered.
        #   - NextDNS, encrypted, your profile.   <-- PROFILE ID placeholder
        #   - Work DNS, plain, only reachable on the corporate subnet.
        upstream_dns = [
          "tls://dns.adguard-dns.com"
          "https://dns.adguard-dns.com/dns-query"
          # --- replace <profile-id> with your NextDNS profile identifier ---
          "https://dns.nextdns.io/<profile-id>"
          # --- replace with the real corporate resolver, e.g. 192.168.1.1 ---
          "192.168.XX.XX"
        ];

        # Bootstrap servers, used ONLY to resolve the hostnames of the DoT/DoH
        # upstreams above (dns.adguard-dns.com, dns.nextdns.io) — a resolver can
        # not ask itself to look up its own upstream. Never used for general
        # queries, so it does not violate "one DNS": every real lookup still
        # goes through the pool above.
        bootstrap_dns = [
          "9.9.9.9"
          "149.112.112.112"
        ];
      };

      # Query log and stats off: no DNS history written to disk. Keeps the box
      # from accumulating a record of every name it ever resolved.
      querylog = {
        enabled = false;
        interval = 0;
      };
      statistics = {
        enabled = false;
        interval = 0;
      };
    };
  };
}
