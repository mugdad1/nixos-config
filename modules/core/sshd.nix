{username, ...}: {
  # sshd, reachable over Tailscale only.
  #
  # The laptop is not a server — nothing on the LAN should be able to knock on
  # :22. Tailscale is already up on this box (modules/core/tailscale.nix), so
  # the way in is the tailnet: WireGuard, identity-bound, and invisible from
  # the wifi network. That is the entire reason the port is allowed on
  # `tailscale0` and nowhere else.
  #
  # Per the rule in network.nix, the inbound port is declared here, next to the
  # service that needs it, so the port cannot outlive sshd. `openFirewall` stays
  # false — it would open :22 on *every* interface, which is the opposite of
  # what this is for.
  services.openssh = {
    enable = true;
    openFirewall = false;

    settings = {
      # Key-only. A password on an internet-adjacent daemon is a thing to guess
      # at; a 256-bit ed25519 key is not. There is already a key on this box
      # (~/.ssh/id_ed25519), so key-only does not lock anyone out.
      PasswordAuthentication = false;
      KbdInteractiveAuthentication = false;
      PermitRootLogin = "no";

      # Only the account that owns this laptop. No shared or service logins.
      AllowUsers = [username];
    };
  };

  # The one inbound port on this machine, and only on the tailnet interface.
  # `tailscale0` is created by tailscaled, so the interface existing is not a
  # precondition — the firewall rule simply matches once it does.
  networking.firewall.interfaces.tailscale0.allowedTCPPorts = [22];

  # No `programs.ssh.startAgent` here, deliberately. It cannot be enabled
  # alongside `services.gnome.gcr-ssh-agent`, which is already on because
  # desktop/services.nix sets `services.gnome.gnome-keyring.enable` — NixOS
  # asserts that only one ssh agent may exist. The keyring's gcr-ssh-agent is
  # also the better of the two on a desktop: it unlocks with the login session
  # and holds the passphrase for you, so ssh to the ThinkCentre and
  # git-over-ssh both run without prompting. Adding a second agent here would
  # have taken that away, not improved it.
}
