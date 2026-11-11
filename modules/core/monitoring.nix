# sops wiring — grandpa only. The laptops hold no age key and declare no
# secrets. Disk/unit monitoring is deliberately absent: there is no delivery
# transport, so failures live in journald and `systemctl --failed`.
{
  lib,
  host,
  ...
}: {
  sops = lib.mkIf (host == "grandpa") {
    defaultSopsFile = lib.mkDefault ../../secrets/fleet.sops.yaml;

    # The private key must be restored here before the first switch on a fresh
    # install; it is the one thing the flake cannot reproduce.
    age.keyFile = lib.mkDefault "/var/lib/sops-nix/key.txt";
  };
}
