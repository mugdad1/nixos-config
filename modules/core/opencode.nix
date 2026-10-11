{
  inputs,
  ...
}: {
  # sst/opencode overlay: replaces nixpkgs' stale opencode with v2
  nixpkgs.overlays = [
    inputs.opencode.overlays.default
  ];
}
