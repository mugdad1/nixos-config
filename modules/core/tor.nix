{
  host,
  lib,
  pkgs,
  ...
}:
# Tor as a client only, on EVERY host: no relay, no exit, no transparent proxy,
# no DNS interception. The single thing it exposes is SOCKS5 on 127.0.0.1:9050
# (client.enable's default, with IsolateDestAddr), so traffic is on Tor only when
# an application asks for that proxy — tor-browser already finds it unaided
# (modules/home/apps/gui.nix).
#
# client.enable is required, not cosmetic: bare `services.tor.enable = true`
# runs a daemon with no listeners at all — "without relay, exit, bridge or client
# connectivity", the option's own words — which looks enabled and routes nothing.
let
  # The two machines that ever sit behind real DPI: victus now, t480s from
  # 2026-11-06. Both go to the university (Fortinet), which drops direct Tor.
  # grandpa is the home box we tunnel *to*: it runs the plain daemon and none
  # of the transports, because a bridge plugin there would be dead weight.
  dpi = builtins.elem host ["victus" "t480s"];
in {
  services.tor = {
    enable = true;
    client.enable = true;

    # settings, not extraConfig: this nixpkgs removed extraConfig and asserts
    # that it "no longer has any effect". The freeform settings attrs render as
    # plain torrc lines, including the %include directive.
    settings = lib.mkIf dpi {
      # Snowflake: the transport that needs no bridge line, because the point is
      # that volunteers are discovered through the broker. It is the default
      # here only because every other option needs a line we cannot fetch from a
      # blocked network. The broker is the stock one: the CDN77/datapacket
      # fronts also advertised by the moat map were blocked from home, so
      # fronting bought nothing. STUN is explicit because the client must learn
      # its public address before any proxy will pair with it, and Google's STUN
      # is blocked while these three answered.
      ClientTransportPlugin = [
        "snowflake exec ${pkgs.snowflake}/bin/client -url https://snowflake-broker.torproject.net/ -ice stun:stun.epygi.com:3478,stun:stun.telnyx.com:3478,stun:stun.cloudflare.com:3478"
        # obfs4 is the transport that actually beats Fortinet-class DPI, but it
        # needs a bridge line from BridgeDB, which cannot be fetched from the
        # network it is meant to bypass. The lines live OUTSIDE this repo on
        # purpose: a bridge committed to a public git repo is burned within
        # hours and then helps nobody.
        "obfs4 exec ${pkgs.obfs4}/bin/lyrebird"
      ];
      UseBridges = true;
      Bridge = "snowflake 192.0.2.3:80 2B280B23E1107BB62ABFC40DDCC8824814F80A72";
      # The file exists only so this include never fails; empty means snowflake
      # is the only transport tried. To switch, write real lines to
      # /var/lib/tor/bridges.conf (0600) and `systemctl restart tor`:
      #   Bridge obfs4 <ip>:<port> <fingerprint> cert=<cert> iat-mode=0
      # BridgeDB: https://bridges.torproject.org/ or @GetBridgesBot on Telegram.
      "%include" = "/var/lib/tor/bridges.conf";
    };
  };

  # `%include` of a missing file is a hard tor startup failure, so the file must
  # exist even when no bridge has been added yet. `f` creates it only when
  # absent, so it never overwrites lines written later.
  systemd.tmpfiles.rules = lib.mkIf dpi [
    "f /var/lib/tor/bridges.conf 0600 tor tor -"
  ];

  environment.systemPackages = lib.optionals dpi [
    pkgs.snowflake
    pkgs.obfs4 # ships lyrebird, the maintained obfs4proxy successor
  ];
}
