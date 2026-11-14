# Host-local sops wiring. Same ciphertext as grandpa (secrets/fleet.sops.yaml);
# asus holds the fleet age key so filen-sync can render its env file. It has
# no searxng template — that service lives on grandpa.
{
  ...
}: {
  sops = {
    defaultSopsFile = ../../secrets/fleet.sops.yaml;

    # Machine state, not user state: sops-install-secrets runs early in boot.
    age.keyFile = "/var/lib/sops-nix/key.txt";
  };
}
