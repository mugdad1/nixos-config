# Ollama on the Victus — the upstream v0.40.15 source build (../../pkgs/ollama.nix),
# CUDA on the RTX 3050. Two facts drive this file:
#
#   * `mimo-v2.6` is the only declared model. It is Xiaomi MiMo's 9B code/agent
#     model, supported from Ollama v0.40.15; v0.40.13 in the locked nixpkgs does
#     not know it, which is the entire reason the package is pinned.
#   * `:11434` is reachable from the tailnet and nowhere else. The service binds
#     0.0.0.0 because systemd cannot know which interface tailscale0 will use
#     before tailscaled is up; the firewall is what actually scopes it.
#
# GPU inference needs `gpu-mode hybrid`: Cardwire's default `intel` mode removes
# the RTX 3050 from the bus, and CUDA then has no device to enumerate. CPU
# fallback still works in that mode, just slowly.
{pkgs, ...}: let
  ollama = pkgs.callPackage ../../pkgs/ollama.nix {};
in {
  services.ollama = {
    enable = true;
    package = ollama;

    host = "0.0.0.0";
    port = 11434;

    # One model, pulled by ollama-model-loader.service after the server starts.
    # Re-running pull on later boots is a no-op once the manifest is present.
    loadModels = ["mimo-v2.6"];

    # Deliberately not `openFirewall`: that opens the port on every interface,
    # including wlan0/eth0. The rule below is tailnet-only.
    openFirewall = false;
  };

  networking.firewall.interfaces."tailscale0".allowedTCPPorts = [11434];
}
