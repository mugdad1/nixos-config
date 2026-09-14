{
  pkgs,
  lib,
  ...
}: let
  g = (import ../../lib/gruvbox.nix).raw;
  kwmPkg = pkgs.callPackage ../../packages/kwm.nix {};
  kwimPkg = pkgs.callPackage ../../packages/kwim.nix {};
  # kwm spawns `kwim` by name on startup/input-hotplug — guarantee it is
  # on PATH regardless of what the greetd session inherits.
  kwm = pkgs.symlinkJoin {
    name = "kwm-wrapped";
    paths = [kwmPkg];
    buildInputs = [pkgs.makeWrapper];
    postBuild = ''
      wrapProgram $out/bin/kwm --prefix PATH : ${kwimPkg}/bin
    '';
  };

  # greeter theme
  greeterTheme = "container=#${g.bg0_h};border=#${g.green};text=#${g.fg};prompt=#${g.yellow};time=#${g.gray};action=#${g.blue};button=#${g.aqua};title=#${g.bright_blue};greet=#${g.bright_green};input=#${g.fg}";
  # single-token session command (tuigreet -c would clobber --cmd)
  sessionCommand = pkgs.writeShellScript "river-session" "${pkgs.river}/bin/river -c ${kwm}/bin/kwm";
in {
  services = {
    gvfs.enable = true;

    gnome = {
      gnome-keyring.enable = true;
    };

    fstrim = {
      enable = true;
      interval = "daily";
    };
    fwupd.enable = true;

    logind.settings.Login = {
      # don’t shutdown when power button is short-pressed
      HandlePowerKey = "ignore";

      # ignore lid close (hosts can override via mkForce)
      HandleLidSwitch = lib.mkDefault "ignore";
      HandleLidSwitchExternalPower = lib.mkDefault "ignore";
      HandleLidSwitchDocked = lib.mkDefault "ignore";
    };

    udisks2.enable = true;

    greetd = {
      enable = true;
      settings = {
        default_session = {
          command = "${pkgs.tuigreet}/bin/tuigreet --time --asterisks --remember --theme '${greeterTheme}' --cmd ${sessionCommand}";
          user = "greeter";
        };
      };
    };

    irqbalance.enable = true;
    bpftune.enable = true;
  };

  services.upower = {
    enable = true;
    percentageLow = 20;
    percentageCritical = 5;
    percentageAction = 3;
    criticalPowerAction = "PowerOff";
  };

  zramSwap = {
    enable = true;
    algorithm = "zstd";
  };
}
