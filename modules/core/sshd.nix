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

  # Password auth is still the only path on victus, so brake repeated failures.
  services.fail2ban = {
    enable = true;
    maxretry = 5;
    bantime = "1h";
  };
}
