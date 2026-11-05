{
  inputs,
  config,
  lib,
  pkgs,
  ...
}: let
  # nix-flatpak generates the activation-time installer as
  # `flatpak-managed-install.service` (Type=oneshot, zero user environment:
  # no DISPLAY, no DBUS_SESSION_BUS_ADDRESS). When it has real work to do the
  # first time — installing the Craft Apps via modules/desktop/artcraft.nix —
  # flatpak tries to autolaunch a session bus and dies before doing any work:
  #
  #   error: Cannot autolaunch D-Bus without X11 $DISPLAY   (exit 4, activation fails)
  #
  # DBUS_SYSTEM_BUS_ADDRESS doesn't help and pointing
  # DBUS_SESSION_BUS_ADDRESS at the system bus fails with "The name is not
  # activatable" — flatpak wants a session bus. So run the generated script
  # under a private session bus. The script import below is byte-identical
  # to the one nix-flatpak uses to build ExecStart (same module, same args),
  # so the only change is the bus wrapper around it. If nix-flatpak ever
  # restructures and this breaks at evaluation time, that is deliberate.
  managedInstallScript = import "${inputs.nix-flatpak.outPath}/modules/script/flatpak-managed-install.nix" {
    inherit pkgs lib;
    cfg = config.services.flatpak;
    installation = "system";
    executionContext = "service-start";
  };

  # Run the generated script under a private session bus. dbus-run-session
  # can't find dbus-daemon on its own inside this unit — the unit's PATH has
  # no dbus — so the wrapper prepends it.
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
        # Force Wayland by default
        Context.sockets = [
          "wayland"
          "!x11"
          "!fallback-x11"
        ];
      };
    };
  };
}
