{ ... }:
{
  services.adguardhome = {
    enable = true;
    host = "127.0.0.1";
    port = 3000;
    openFirewall = true;
    mutableSettings = false;
    settings = {
      users = [
        {
          name = "mugdad";
          password = "$2b$05$Ql8dSXIbLyBwncygqV.2JeTW6Kiop/sWmDLYaMGJXzMzbOKqyM.G.";
        }
      ];
      dns = {
        bind_hosts = [ "127.0.0.1" ];
        port = 53;
        upstream_dns = [
          "94.140.14.14"
          "94.140.15.15"
        ];
        fallback_dns = [
          "9.9.9.9"
          "149.112.112.112"
        ];
        bootstrap_dns = [
          "94.140.14.14"
          "94.140.15.15"
        ];
        upstream_mode = "parallel";
        blocking_mode = "nxdomain";
        ratelimit = 0;
        refuse_any = true;
        cache_size = 8388608;
        cache_ttl_min = 60;
        cache_ttl_max = 14400;
        cache_optimistic = true;
        anonymize_client_ip = true;
        edns_client_subnet = {
          enabled = true;
        };
      };
      filtering = {
        protection_enabled = true;
        filtering_enabled = true;
        parental_enabled = false;
        safe_search = { enabled = false; };
        safebrowsing_enabled = false;
      };
      filters = map (url: { enabled = true; url = url; }) [
        # General
        "https://adguardteam.github.io/HostlistsRegistry/assets/filter_1.txt"
        "https://adguardteam.github.io/HostlistsRegistry/assets/filter_3.txt"
        "https://adguardteam.github.io/HostlistsRegistry/assets/filter_4.txt"
        "https://adguardteam.github.io/HostlistsRegistry/assets/filter_5.txt"
        "https://adguardteam.github.io/HostlistsRegistry/assets/filter_24.txt"
        "https://adguardteam.github.io/HostlistsRegistry/assets/filter_33.txt"
        "https://adguardteam.github.io/HostlistsRegistry/assets/filter_34.txt"
        "https://adguardteam.github.io/HostlistsRegistry/assets/filter_53.txt"
        "https://adguardteam.github.io/HostlistsRegistry/assets/filter_59.txt"
        "https://adguardteam.github.io/HostlistsRegistry/assets/filter_69.txt"
        # Security
        "https://adguardteam.github.io/HostlistsRegistry/assets/filter_8.txt"
        "https://adguardteam.github.io/HostlistsRegistry/assets/filter_9.txt"
        "https://adguardteam.github.io/HostlistsRegistry/assets/filter_10.txt"
        "https://adguardteam.github.io/HostlistsRegistry/assets/filter_11.txt"
        "https://adguardteam.github.io/HostlistsRegistry/assets/filter_12.txt"
        "https://adguardteam.github.io/HostlistsRegistry/assets/filter_18.txt"
        "https://adguardteam.github.io/HostlistsRegistry/assets/filter_30.txt"
        "https://adguardteam.github.io/HostlistsRegistry/assets/filter_31.txt"
        "https://adguardteam.github.io/HostlistsRegistry/assets/filter_42.txt"
        "https://adguardteam.github.io/HostlistsRegistry/assets/filter_44.txt"
        "https://adguardteam.github.io/HostlistsRegistry/assets/filter_55.txt"
        "https://adguardteam.github.io/HostlistsRegistry/assets/filter_71.txt"
        # Other
        "https://adguardteam.github.io/HostlistsRegistry/assets/filter_6.txt"
        "https://adguardteam.github.io/HostlistsRegistry/assets/filter_7.txt"
        "https://adguardteam.github.io/HostlistsRegistry/assets/filter_39.txt"
        "https://adguardteam.github.io/HostlistsRegistry/assets/filter_47.txt"
        "https://adguardteam.github.io/HostlistsRegistry/assets/filter_57.txt"
        "https://adguardteam.github.io/HostlistsRegistry/assets/filter_60.txt"
        "https://adguardteam.github.io/HostlistsRegistry/assets/filter_61.txt"
        "https://adguardteam.github.io/HostlistsRegistry/assets/filter_63.txt"
        "https://adguardteam.github.io/HostlistsRegistry/assets/filter_65.txt"
        "https://adguardteam.github.io/HostlistsRegistry/assets/filter_66.txt"
        "https://adguardteam.github.io/HostlistsRegistry/assets/filter_67.txt"
      ];
      user_rules = [];
      querylog = {
        enabled = true;
        interval = "168h";
        file_enabled = true;
      };
      statistics = {
        enabled = true;
        interval = "168h";
      };
    };
  };

  services.resolved.enable = false;
}
