{ gpu, pkgs, lib, config, ... }:
let
  cfg = gpu;
in {
  imports = [
    ./amd-nvidia-hybrid.nix
    ./intel.nix
  ];

  config = lib.mkMerge [
    (lib.mkIf (cfg == "amd-nvidia-hybrid") {
      drivers.amd-nvidia-hybrid.enable = true;
    })
    (lib.mkIf (cfg == "intel") {
      drivers.intel.enable = true;
    })
  ];
}
