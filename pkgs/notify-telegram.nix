# notify-telegram - one alert path for every detector on the fleet.
#
# The script body lives in ../../scripts/notify-telegram.sh and the WHY lives
# in that file's header. This wrapper only exists so the same package can be
# put on PATH (modules/core/monitoring.nix) without two copies of the delivery
# logic - there used to be three failing detectors and zero delivery paths, and
# the fix is not three new ones. sv-watch used to pull the same package into
# its runtimeInputs; that wrapper is gone with sv-watch (2026-10-23), so this
# one now serves PATH and the OnFailure= template unit.
#
# It is a `callPackage` file like pkgs/filen-cli.nix because modules/core is
# scanned by lib/default.nix and cannot see a `let` binding inside a host file.
{
  writeShellApplication,
  coreutils,
  curl,
  inetutils, # hostname
  gnused, # the Subject: pick-out
}:
writeShellApplication {
  name = "notify-telegram";
  runtimeInputs = [
    coreutils
    curl
    inetutils
    gnused
  ];
  # The file keeps its own `#!/bin/sh` line: writeShellApplication prepends its
  # shebang and the shellcheck/errexit preamble, and a second shebang line is a
  # comment.
  text = builtins.readFile ../scripts/notify-telegram.sh;
}
