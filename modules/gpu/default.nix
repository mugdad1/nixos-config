{ gpu, lib, ... }:
{
  imports = [
    ./amd-nvidia-hybrid.nix
  ];

  config = lib.mkIf (gpu == "amd-nvidia-hybrid") {
    drivers.amd-nvidia-hybrid.enable = true;
  };
}
