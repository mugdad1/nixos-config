{
  host,
  lib,
  pkgs,
  ...
}:
# zapret (https://github.com/bol-van/zapret) — nfqws desynchronises the first
# packets of a TCP flow so a DPI box that matches on the ClientHello/SNI loses
# track of the connection. It is a blunt instrument, and it is deliberately NOT
# started at boot: the right args depend on the exact DPI in front of you, a
# wrong preset breaks more than it fixes, and none of it can be tuned without
# standing on the network it is meant to beat.
#
# THE EXCLUSIONS ARE THE IMPORTANT PART, because this is the one tool here that
# could take Tailscale down — and Tailscale is how the home server stays
# reachable from campus:
#   * the nft rule skips the CGNAT range (100.64.0.0/10, where every tailnet
#     address lives), the tailscale0 interface and the private LAN ranges;
#   * nfqws itself skips the tailscale domains by SNI, because Tailscale's DERP
#     fallback is ordinary TCP 443 to derpN.tailscale.com — outside CGNAT, so
#     the nft rule alone would not save it.
# Direct WireGuard is UDP and is never queued: the nft rule filters tcp only.
let
  dpi = builtins.elem host ["victus" "t480s"];

  # nfqws reads these as SNI/Host names and applies them to subdomains, so
  # `tailscale.com` also covers derp1.tailscale.com and controlplane.
  tailscaleHosts = pkgs.writeText "zapret-tailscale-exclude.txt" ''
    tailscale.com
    tailscale.io
    tailscale.net
    ts.net
  '';

  # Least destructive first attempt: split the ClientHello after its first byte
  # and inject nothing. `split2` alone beats simple SNI filters; fake-packet
  # modes (`fake`, `fakedsplit`) are the next step if this does nothing, and
  # they need a TTL that matches the path. Override without a rebuild:
  #   cat /etc/zapret/default-args > /var/lib/zapret/args   # then edit
  #   systemctl restart zapret
  defaultArgs = "--filter-tcp=80,443 --dpi-desync=split2 --dpi-desync-split-pos=1";

  start = pkgs.writeShellScript "zapret-start" ''
    set -eu
    PATH=${lib.makeBinPath [pkgs.nftables pkgs.zapret pkgs.coreutils]}

    # Rebuild our table from scratch so a restart cannot stack duplicate rules.
    nft delete table inet zapret 2>/dev/null || true
    nft add table inet zapret
    nft 'add chain inet zapret output { type filter hook output priority 0; }'

    # First match wins, so every exclusion must sit above the queue rule.
    nft 'add rule inet zapret output ip daddr 127.0.0.0/8 return'
    nft 'add rule inet zapret output ip daddr 100.64.0.0/10 return'
    nft 'add rule inet zapret output oifname "tailscale0" return'
    nft 'add rule inet zapret output ip daddr 10.0.0.0/8 return'
    nft 'add rule inet zapret output ip daddr 172.16.0.0/12 return'
    nft 'add rule inet zapret output ip daddr 192.168.0.0/16 return'
    nft 'add rule inet zapret output tcp dport { 80, 443 } queue num 200 bypass'

    ARGS=""
    if [ -s /var/lib/zapret/args ]; then
      ARGS=$(cat /var/lib/zapret/args)
    fi
    if [ -z "$ARGS" ]; then
      ARGS="${defaultArgs}"
    fi

    # Unquoted on purpose: the arg line is several flags, not one.
    # shellcheck disable=SC2086
    exec nfqws --qnum=200 --hostlist-exclude=${tailscaleHosts} $ARGS
  '';

  stop = pkgs.writeShellScript "zapret-stop" ''
    PATH=${lib.makeBinPath [pkgs.nftables]}
    nft delete table inet zapret 2>/dev/null || true
  '';
in
  lib.mkIf dpi {
    environment.systemPackages = [pkgs.zapret];
    boot.kernelModules = ["nfnetlink_queue"];

    # Present but not enabled. `systemctl start zapret` to try it,
    # `systemctl stop zapret` to undo it (ExecStopPost removes the nft table, so
    # stopping really restores the previous path). Add it to wantedBy only once
    # a preset has been proven on the network in question.
    systemd.services.zapret = {
      description = "zapret nfqws DPI desync (not started by default)";
      after = ["network-online.target"];
      wants = ["network-online.target"];
      wantedBy = [];
      serviceConfig = {
        Type = "simple";
        ExecStart = start;
        ExecStopPost = stop;
        Restart = "no";
      };
    };

    # The default line only becomes the running one if nobody has tuned it;
    # `f` creates the file empty and never overwrites an edit.
    environment.etc."zapret/default-args".text = defaultArgs;
    systemd.tmpfiles.rules = [
      "d /var/lib/zapret 0755 root root -"
      "f /var/lib/zapret/args 0644 root root -"
    ];
  }
