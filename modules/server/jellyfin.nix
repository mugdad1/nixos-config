# Jellyfin (media). Tailscale only (firewall stays shut, port 8096):
# http://asus:8096 — add /var/lib/jellyfin/media libraries in the UI.
{
  services.jellyfin = {
    enable = true;
  };
}
