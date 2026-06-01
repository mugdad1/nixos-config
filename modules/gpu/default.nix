{ gpu, pkgs, lib, config, ... }:
let
  cfg = gpu;
in {
  imports = [
    ./amd.nix
    ./amd-nvidia-hybrid.nix
    ./intel.nix
    ./nvidia.nix
    ./nvidia-prime.nix
    ./vm.nix
  ];

  config = lib.mkMerge [
    (lib.mkIf (cfg == "amd") {
      drivers.amdgpu.enable = true;
    })
    (lib.mkIf (cfg == "amd-nvidia-hybrid") {
      drivers.amd-nvidia-hybrid.enable = true;
    })
    (lib.mkIf (cfg == "intel") {
      drivers.intel.enable = true;
    })
    (lib.mkIf (cfg == "nvidia") {
      drivers.nvidia.enable = true;
    })
    (lib.mkIf (cfg == "nvidia-prime") {
      drivers.nvidia-prime.enable = true;
    })
    (lib.mkIf (cfg == "vm") {
      drivers.vm.enable = true;
    })
  ];
}
