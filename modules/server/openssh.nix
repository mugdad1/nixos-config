# SSH: password auth is OFF. Access is via Tailscale SSH (tailscaled with
# --ssh proxies port 22 and authenticates against the tailnet ACLs), or
# pubkey auth for LAN access. New machines should still work over Tailscale
# once the tailnet is up; if you need LAN bootstrap access, drop a pubkey
# into users.users.${username}.openssh.authorizedKeys.keys.
{
  services.openssh = {
    enable = true;
    settings = {
      PasswordAuthentication = false;
      KbdInteractiveAuthentication = false;
      PermitRootLogin = "no";
    };
  };
}
