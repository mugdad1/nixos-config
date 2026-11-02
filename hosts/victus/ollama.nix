# Ollama on the Victus — added 2026-10-30, disabled 2026-10-31, BACK 2026-11-01.
#
# The 10-31 removal was right about the symptom and wrong about the cause. The
# comment it left behind says "too slow for local agent use on the 4G 3050",
# and the model that was slow was nemotron-3.5-bolt: ~22 GB against 3.7 GiB of
# usable VRAM, so it ran mostly on the CPU and an agent turn took minutes. The
# card was never the problem — the model was. A 4B at Q4_K_M is 3.3 GB and
# loads 39%/61% CPU/GPU at 16k context, which is fast enough to drive opencode.
#
# WHAT MAKES IT AN AGENT, and what does not: Ollama cannot read files. A model
# is a text generator; `ollama run` has no filesystem. The reading is done by
# opencode, which sends the model a JSON list of tools (read, grep, glob, shell,
# edit, write, webfetch, question, subagent) and executes whatever the model
# asks for, then feeds the result back. So the requirements on this side are
# only two: the model must emit valid tool calls, and its context window must
# be big enough to hold opencode's system prompt + tool schemas.
#
#   tools      qwen3.5 has them natively (`ollama show` says capabilities:
#              completion, vision, tools, thinking).
#   context    THE DEFAULT IS 4096 and that silently truncates opencode's
#              prompt. OLLAMA_CONTEXT_LENGTH below is what makes it 32k; a
#              bigger number is not free — KV cache eats the same 4 GiB the
#              weights need. 32k is the tested value.
#
# Model choices, sized for the 4 GiB card:
#   qwen3.5:4b   3.3 GB Q4_K_M, 256K context, tools + vision. The one that
#                actually fits the 3050 and drives opencode's tools correctly;
#                back as the default 2026-11-02 (24s for the write-a-file task,
#                10.9 tok/s at 32k with the flags below).
#   qwen3.5:2b   2.7 GB, chat only. It has the tools capability on paper but
#                in practice it confused `execute` with `shell`, retried, and
#                never finished the same task the 4b did in 24s. It stays for
#                `ollama run` quick questions, NOT as an opencode fallback.
# Deliberately gone: nemotron-3-nano:4b — it has the tools capability but in
# practice hallucinated tool names instead of calling them.
# REMOVED 2026-11-02 ("find me other model … not slow"): nemotron-3.5-bolt:e4b.
# At 7.2–7.9 GB against 3.7 GiB of usable VRAM it ran mostly on the CPU — the
# same failure mode as the old 22 GB model. qwen3.5:4b is the replacement.
# syncModels = false means the nemotron blob is NOT deleted from disk; reclaim
# the ~8 GB with `ollama rm nemotron-3.5-bolt:e4b`.
#
# GPU CAVEAT, unchanged: Cardwire's `integrated` mode (the default in
# /var/lib/victus/gpu-mode) removes the dGPU from the PCI bus, so CUDA cannot
# see it and Ollama falls back to CPU. For GPU inference run `gpu-mode hybrid`
# (or `nvidia`), then `sudo systemctl restart ollama`. Runtime switch, not a
# rebuild.
#
# NETWORK POSTURE — tailnet only, like every other service in this repo. The
# server binds 0.0.0.0 so the tailnet address answers, but the firewall below
# opens 11434 on tailscale0 alone; the LAN gets nothing. `openFirewall` is
# deliberately NOT set: that option adds the port to every interface, which is
# the same mistake the old compose stack made.
{pkgs, ...}: {
  services.ollama = {
    enable = true;

    # The option is `package`, not `acceleration`: nixpkgs removed
    # services.ollama.acceleration, so naming ollama-cuda is the supported way
    # to pick the CUDA build. It is what makes the RTX 3050 usable at all.
    #
    # `cudaArches` defaults to cudaPackages.flags.realArches, which is every
    # architecture nixpkgs knows about (sm_75/80/86/89/90/100/103/107/120/121).
    # Nothing is cached, so all ten get compiled locally — on this laptop that
    # pinned every core and made the machine unusable. The RTX 3050 Laptop
    # (GA107) is sm_86, so build for that one arch only. ~10x less work.
    package = pkgs.ollama-cuda.override {
      cudaArches = ["sm_86"];
    };

    # Reachable from the tailnet; the firewall rule below keeps it off the LAN.
    host = "0.0.0.0";
    port = 11434;

    # The three knobs that keep this from becoming "heavy on my device":
    #
    #   OLLAMA_CONTEXT_LENGTH   the 4096 default truncates opencode's system
    #                           prompt. 32768 is the tested size; every extra
    #                           token of context is KV cache in the same VRAM.
    #   OLLAMA_MAX_LOADED_MODELS  one model resident, never two. Without it a
    #                           second model load evicts the first and both end
    #                           up partly on the CPU.
    #   OLLAMA_NUM_PARALLEL     one request at a time — a laptop, not a server.
    #                           Parallel slots multiply the KV cache.
    environmentVariables = {
      OLLAMA_CONTEXT_LENGTH = "32768";
      OLLAMA_MAX_LOADED_MODELS = "1";
      OLLAMA_NUM_PARALLEL = "1";
      # Generation on a 4 GB card is KV-cache bound, not weight bound. With
      # f16 KV and no flash attention the 4B managed 6.3 tok/s at 32k; with
      # these two it does 10.9 tok/s at the same context (measured 2026-11-01,
      # 30k-token prompt). q8_0 halves the cache so more layers stay on the
      # GPU. Requires flash attention, which is why they move together.
      OLLAMA_FLASH_ATTENTION = "1";
      OLLAMA_KV_CACHE_TYPE = "q8_0";
    };

    # Pulled in the background by ollama-model-loader.service after the server
    # starts. First activation therefore downloads them asynchronously and does
    # NOT hold up switch-to-configuration.
    loadModels = [
      "qwen3.5:4b"
      "qwen3.5:2b"
    ];

    # Do not silently delete anything pulled by hand with `ollama pull`;
    # declaring models here is additive.
    syncModels = false;
  };

  # Tailnet only — not networking.firewall.allowedTCPPorts (see header).
  networking.firewall.interfaces."tailscale0".allowedTCPPorts = [11434];
}
