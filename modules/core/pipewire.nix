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

      extraConfig.pipewire = {
        "context.properties" = {
          default.clock.allowed-rates = [
            44100
            48000
            96000
            192000
          ];
          default.clock.quantum = 256;
          default.clock.min-quantum = 32;
          default.clock.max-quantum = 8192;
        };
      };
    };
  };

  environment.systemPackages = with pkgs; [alsa-utils];
}
