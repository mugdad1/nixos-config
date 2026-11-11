# Host-local secret templates. Values are ciphertext in
# secrets/fleet.sops.yaml; this file only declares what grandpa renders.
{
  config,
  username,
  ...
}: {
  sops = {
    defaultSopsFile = ../../secrets/fleet.sops.yaml;

    # Machine state, not user state: sops-install-secrets runs early in boot.
    age.keyFile = "/var/lib/sops-nix/key.txt";

    secrets."searx/secret_key" = {};

    templates."searxng.env" = {
      owner = username;
      mode = "0400";
      content = ''
        SEARX_SECRET_KEY=${config.sops.placeholder."searx/secret_key"}
      '';
    };
  };
}
