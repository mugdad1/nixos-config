# SSH: key-only by default. PasswordAuthentication is currently ON so new
# machines can be bootstrapped over LAN. Flip it back to false once keys are
# deployed.
{
  services.openssh = {
    enable = true;
    settings = {
      PasswordAuthentication = true;
      PermitRootLogin = "no";
    };
  };
}
