_: {
  services.tailscale = {
    enable = true;
    # Opens UDP 41641 in the module that needs it (see README's firewall rule).
    openFirewall = true;

    # Tailscale must never own DNS: the local resolver (AdGuard Home, once it
    # owns 127.0.0.1:53) is the only one on the box, and MagicDNS would overwrite
    # /etc/resolv.conf with 100.100.100.100 plus a search domain.
    #
    # Both lists, because they cover different moments:
    #   extraUpFlags    - passed to `tailscale up`, so a fresh login is born with
    #                     DNS off (only applied when services.tailscale.authKeyFile
    #                     is set, kept for that case).
    #   extraSetFlags   - `tailscale set` runs after every tailscaled start, so a
    #                     later `tailscale up` (which resets any flag it was not
    #                     given back to its default, accept-dns included) cannot
    #                     silently re-enable it.
    extraUpFlags = ["--accept-dns=false"];
    extraSetFlags = ["--accept-dns=false"];
  };

  # tailscaled builds its own WireGuard interface, so packets from peers are
  # asymmetric by design: strict rpfilter drops them once subnet routes or exit
  # nodes are in play. `loose` is Tailscale's documented requirement.
  networking.firewall.checkReversePath = "loose";
}
