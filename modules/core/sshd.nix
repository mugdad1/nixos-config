{username, ...}: {
  services.openssh = {
    enable = true;
    openFirewall = true;

    settings = {
      PasswordAuthentication = true;
      KbdInteractiveAuthentication = false;
      PermitRootLogin = "no";
      AllowUsers = [username];
    };
  };

  # Password auth is still the only path (no authorized_keys on victus yet),
  # so put a brake on repeated failures. Key-only login remains a separate
  # decision; fail2ban does not replace it.
  services.fail2ban = {
    enable = true;
    maxretry = 5;
    bantime = "1h";
  };
}
