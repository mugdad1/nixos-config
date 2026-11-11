{
  inputs,
  config,
  lib,
  pkgs,
  ...
}: let
  # nix-flatpak's install unit runs with no session bus, which makes flatpak
  # die with "Cannot autolaunch D-Bus without X11 $DISPLAY" on first install.
  # Reuse the module's own script, wrapped in a private session bus.
  managedInstallScript = import "${inputs.nix-flatpak.outPath}/modules/script/flatpak-managed-install.nix" {
    inherit pkgs lib;
    cfg = config.services.flatpak;
    installation = "system";
    executionContext = "service-start";
  };

  managedInstallWithBus = pkgs.writeShellScript "flatpak-managed-install-with-session-bus" ''
    export PATH="${pkgs.dbus}/bin:$PATH"
    exec ${pkgs.dbus}/bin/dbus-run-session ${managedInstallScript}
  '';
in {
  imports = [inputs.nix-flatpak.nixosModules.nix-flatpak];

  systemd.services.flatpak-managed-install.serviceConfig.ExecStart =
    lib.mkForce "${managedInstallWithBus}";

  services.flatpak = {
    enable = true;
    overrides = {
      global = {
        Context.sockets = [
          "wayland"
          "!x11"
          "!fallback-x11"
        ];
      };
    };
  };
}
