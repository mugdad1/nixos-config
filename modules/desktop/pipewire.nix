{pkgs, ...}: {
  services = {
    pipewire = {
      enable = true;
      pulse.enable = true;
      wireplumber.enable = true;

      alsa = {
        enable = true;
        support32Bit = true;
      };

      # Each key under extraConfig.pipewire is a drop-in file name; its value
      # is the file body, so keep the "context.properties" wrapper and quote
      # dotted property names.
      extraConfig.pipewire = {
        "10-clock-and-x11-bell" = {
          "context.properties" = {
            "default.clock.allowed-rates" = [
              44100
              48000
              96000
              192000
            ];
            "default.clock.quantum" = 256;
            "default.clock.min-quantum" = 32;
            "default.clock.max-quantum" = 8192;

            # This module segfaults when sway's on-demand Xwayland exits; it is
            # pointless on a Wayland-only session anyway.
            "module.x11.bell" = false;
          };
        };
      };
    };
  };

  environment.systemPackages = with pkgs; [alsa-utils];
}
