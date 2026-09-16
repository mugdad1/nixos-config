# Cockpit (web dashboard + terminal). Tailscale only (firewall stays shut):
# https://asus:9090 — accept the self-signed cert warning once in Zen.
{
  services.cockpit = {
    enable = true;
    port = 9090;
    openFirewall = false;
  };
}
