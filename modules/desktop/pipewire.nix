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

      # Each key under extraConfig.pipewire is a drop-in FILE name; its value is
      # the file body, so the body must contain the section wrapper
      # ("context.properties") and the property names must stay dotted (quoted
      # attr names). Unquoted `default.clock.rate` would become a nested Nix
      # attrset and render as nested JSON, which PipeWire ignores.
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

            # PipeWire 1.6.9's libpipewire-module-x11-bell (pulled in by the
            # stock pipewire.conf) segfaults in libspa-support.so when sway's
            # on-demand Xwayland exits after its 10s idle timeout. That takes
            # down the whole daemon, so an in-flight OBS screencast dies with
            # "Broken pipe" and pulse clients lose their server. The stock
            # config guards the module with
            #   condition = [ { module.x11.bell = !false } ]
            # so setting the property false skips loading it. All the module
            # does is play X11 bell events through libcanberra, which is
            # pointless on this Wayland-only session.
            "module.x11.bell" = false;
          };
        };
      };
    };
  };

  environment.systemPackages = with pkgs; [alsa-utils];
}
