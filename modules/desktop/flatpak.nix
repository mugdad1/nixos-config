{inputs, config, lib, pkgs, ...}: let
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
  # under a private session bus via dbus-run-session. The script import below
  # is byte-identical to the one nix-flatpak uses to build ExecStart (same
  # module, same args), so the only change is the bus wrapper around it.
  # Keep the same pinned input as the import in ./flatpak.nix above — this
  # breaks loudly (path not found) if nix-flatpak restructures, which is what
  # you want. REVISIT if activation ever succeeds without this: delete the
  # ExecStart override.
  managedInstallScript =
    import "${inputs.nix-flatpak.outPath}/modules/script/flatpak-managed-install.nix" {
      inherit pkgs lib;
      cfg = config.services.flatpak;
      installation = "system";
      executionContext = "service-start";
    };
in {
  imports = [inputs.nix-flatpak.nixosModules.nix-flatpak];

  systemd.services.flatpak-managed-install.serviceConfig.ExecStart =
    lib.mkForce "${pkgs.dbus}/bin/dbus-run-session ${managedInstallScript}";

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
