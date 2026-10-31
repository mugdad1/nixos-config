# Ollama on the Victus — added 2026-10-30 on his ask ("add ollama to victus
# with open to tailscale and others").
#
# Why this host and not the others: the RTX 3050 is the only CUDA-capable GPU
# in the fleet (grandpa's GT 210 was pulled 2026-10-25 and its legacy driver no
# longer exists; the t480s is Intel-only). The models below are also sized for
# a laptop that is awake, not for a 6 GiB headless server.
#
# NETWORK POSTURE — tailnet only, like every other service in this repo. The
# server binds 0.0.0.0 so the tailnet address answers, but the firewall below
# opens 11434 on tailscale0 alone; the LAN gets nothing. `openFirewall` is
# deliberately NOT set: that option adds the port to every interface, which is
# the same mistake the old compose stack made.
#
# GPU CAVEAT, worth knowing before wondering why it is slow: Cardwire's
# `integrated` mode (the default in /var/lib/victus/gpu-mode) removes the dGPU
# from the PCI bus, so CUDA cannot see it and Ollama falls back to CPU. For GPU
# inference run `gpu-mode hybrid` (or `nvidia`), then
# `sudo systemctl restart ollama`. This is a runtime switch, not a rebuild —
# the driver stack stays loaded in every mode by design (see default.nix).
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

    # Pulled in the background by ollama-model-loader.service after the server
    # starts. First activation therefore downloads them asynchronously and does
    # NOT hold up switch-to-configuration. Sizes (2026-10-30): granite4.2 3b
    # ~2G, qwen3.5 2b ~1.4G, nemotron-3-nano 4b ~2.8G, nemotron-3.5-bolt
    # latest ~22G — the last one spills past the 4 GiB VRAM and runs partly on
    # CPU by design.
    #
    # `lfm3:1.7b` is deliberately absent: upstream requires ollama >= 0.40.13,
    # while nixpkgs 26.11 pins 0.40.6, so the pull fails with
    # "model requires ollama version v0.40.13 or newer". Leaving it in the list
    # makes ollama-model-loader exit 123 and restart forever. Add it back once
    # nixpkgs carries a newer ollama.
    loadModels = [
      "granite4.2:3b"
      "qwen3.5:2b"
      "nemotron-3-nano:4b"
      "nemotron-3.5-bolt"
    ];

    # Do not silently delete anything pulled by hand with `ollama pull`;
    # declaring models here is additive.
    syncModels = false;
  };

  # Tailnet only — not networking.firewall.allowedTCPPorts (see header).
  networking.firewall.interfaces."tailscale0".allowedTCPPorts = [11434];
}
