# SSH: key-only. Bootstrap note — on a FRESH install with no key deployed
# yet, temporarily set PasswordAuthentication = true for the first deploy,
# push your key, then flip it back. Never leave passwords on.
{
  services.openssh = {
    enable = true;
    settings = {
      PasswordAuthentication = false;
      PermitRootLogin = "no";
    };
  };
}
