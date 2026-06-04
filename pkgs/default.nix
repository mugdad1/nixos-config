{
  inputs,
  pkgs,
  system,
  ...
}:
{
  maple-mono-custom = pkgs.callPackage ./maple-mono { inherit inputs; };
  pomo = pkgs.callPackage ./pomo { };
}
