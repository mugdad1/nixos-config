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

    # ─── THE ENV BLOCK, RESTORED 2026-11-06 ─────────────────────────────────
    # The mimo rewrite dropped it, and the server fell back to upstream's
    # VRAM-based default — journalctl proof from today:
    #   "vram-based default context total_vram=3.7 GiB default_num_ctx=4096"
    # 4096 silently truncates opencode's prompt. The other extreme is just
    # as wrong: the model file advertises qwen35.context_length = 262144,
    # which cannot run here — q8 KV at 262144 would be ~18 GB against a
    # 4 GiB card. 16384 is sized for THIS rig (i5-12500H, 24 GiB RAM,
    # RTX 3050 4 GiB; mimo-v2.6 9B Q4_K_M = 6.6 GB, split CPU/GPU): q8 KV
    # ≈ 1.2 GB, leaving ~2.5 GB of VRAM for weight layers. The old tested
    # value 32768 belonged to the 3.3 GB qwen3.5:4b — at 9B the KV doubles
    # against double the weights and too little stays on the die.
    #
    # THE NUMBER MUST MATCH limit.context in modules/home/apps/opencode.nix
    # (16384 there, 16384 here). If you raise one, raise the other.
    environmentVariables = {
      OLLAMA_CONTEXT_LENGTH = "16384";
      OLLAMA_MAX_LOADED_MODELS = "1"; # one resident model, never two
      OLLAMA_NUM_PARALLEL = "1"; # a laptop, not a server; slots multiply KV
      # Generation on a 4 GB card is KV-cache bound, not weight bound. These
      # two move together (measured 2026-11-01 on this card: 6.3 → 10.9
      # tok/s at 32k for the 4B — q8_0 halves the cache so more layers stay
      # on the GPU, and it requires flash attention).
      OLLAMA_FLASH_ATTENTION = "1";
      OLLAMA_KV_CACHE_TYPE = "q8_0";
    };

    # Deliberately not `openFirewall`: that opens the port on every interface,
    # including wlan0/eth0. The rule below is tailnet-only.
    openFirewall = false;
  };

  networking.firewall.interfaces."tailscale0".allowedTCPPorts = [11434];
}
