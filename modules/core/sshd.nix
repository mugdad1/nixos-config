{
  config,
  lib,
  username,
  ...
}: {
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

  # The ssh agent belongs to the desktop session, not to a lingering systemd
  # process, so `ssh` to the server (and git-over-ssh) can use the key without
  # typing a passphrase on every single call.
  programs.ssh.startAgent = true;
}
