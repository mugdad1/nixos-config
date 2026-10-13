{username, ...}: {
  # sshd, reachable over Tailscale AND the LAN.
  #
  # CHANGED 2026-10-13 on his word: "allow ssh like normally, in lan, in both"
  # / "i can ssh through lan not tailscale". Until today this opened :22 on
  # `tailscale0` only, and the reasoning was sound — the laptop is not a
  # server, so nothing on the wifi should have been able to knock on it, and
  # the tailnet (WireGuard, identity-bound, invisible from the LAN) was the
  # intended way in. That held until the ThinkCentre needed hands-on ssh from
  # the LAN, at which point tailnet-only became the thing in the way.
  #
  # So `openFirewall = true` now: :22 on every interface, which is how sshd is
  # normally configured. This subsumes the old `tailscale0`-only rule rather
  # than stacking on top of it, and it is deliberately NOT pinned to a named
  # LAN interface — the laptop is on iwd/wlan0 and the ThinkCentre on ethernet,
  # and pinning would mean hardcoding two different names that DHCP can move.
  #
  # What keeps this from being careless is that auth is key-only (below). A
  # port open to the wifi with password auth is a thing to brute-force; with
  # `PasswordAuthentication = false` and `PermitRootLogin = "no"` there is no
  # credential to guess, so an open port is just a closed door with no handle.
  # Anyone scanning the network sees :22 and gets nowhere without a key that is
  # already on this box.
  #
  # Per the rule in network.nix, the inbound port is declared here, next to the
  # service that needs it, so the port cannot outlive sshd.
  services.openssh = {
    enable = true;
    openFirewall = true;

    settings = {
      # PASSWORD AUTH, 2026-10-13, on his word ("fix it allow sshing with
      # password"). This reverses the earlier key-only decision: the ThinkCentre
      # install left no key in authorized_keys and he wanted to log in from the
      # LAN without the one-time key paste, so PasswordAuthentication is on.
      #
      # Tradeoff, stated once and not argued: :22 is open to the whole wifi (see
      # openFirewall below) and now accepts passwords, so the daemon is only as
      # strong as the password. Root stays locked out and only his account is
      # reachable, which is the part still worth keeping. To go back to keys,
      # flip this to false and drop the key in ~/.ssh/authorized_keys.
      PasswordAuthentication = true;
      # Passwords only — keyboard-interactive prompts can be scripted around by
      # some clients and adds nothing here once passwords are accepted.
      KbdInteractiveAuthentication = false;
      PermitRootLogin = "no";

      # Only the account that owns this laptop. No shared or service logins.
      AllowUsers = [username];
    };
  };

  # REMOVED 2026-10-13: `networking.firewall.interfaces.tailscale0.allowedTCPPorts = [22]`.
  # It is now redundant — `openFirewall = true` above opens :22 on every
  # interface, tailscale0 included, so keeping it would have been a second rule
  # saying the same thing.

  # No `programs.ssh.startAgent` here, deliberately. It cannot be enabled
  # alongside `services.gnome.gcr-ssh-agent`, which is already on because
  # desktop/services.nix sets `services.gnome.gnome-keyring.enable` — NixOS
  # asserts that only one ssh agent may exist. The keyring's gcr-ssh-agent is
  # also the better of the two on a desktop: it unlocks with the login session
  # and holds the passphrase for you, so ssh to the ThinkCentre and
  # git-over-ssh both run without prompting. Adding a second agent here would
  # have taken that away, not improved it.
}
