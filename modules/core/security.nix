{ ... }:
{
  security = {
    rtkit.enable = true;
    sudo = {
      enable = true;
      wheelNeedsPassword = true;
    };

    pam.services = {
      swaylock = { };
      hyprlock = { };
    };
  };
}
