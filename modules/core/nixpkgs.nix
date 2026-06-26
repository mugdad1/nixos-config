{inputs, ...}: {
  nixpkgs = {
    overlays = [
      (
        final: prev: (import ../../pkgs {
          inherit inputs;
          pkgs = prev;
          system = prev.stdenv.hostPlatform.system;
        })
      )
    ];
  };
}
