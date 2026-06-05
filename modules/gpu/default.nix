{ gpu, pkgs, lib, config, ... }:
let
  cfg = gpu;
in {
  imports = [
    ./amd-nvidia-hybrid.nix
  ];

  config = lib.mkIf (cfg == "amd-nvidia-hybrid") {
    drivers.amd-nvidia-hybrid.enable = true;
  };
}
