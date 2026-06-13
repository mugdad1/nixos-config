{inputs, ...}: {
  nixpkgs = {
    overlays = [
      (
        final: prev: (import ../../pkgs {
          inherit inputs;
          pkgs = prev;
          inherit (prev) system;
        })
      )
    ];
  };
}
