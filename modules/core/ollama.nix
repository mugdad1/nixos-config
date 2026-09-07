{pkgs, ...}: {
  services.ollama = {
    enable = true;
    package = pkgs.ollama-cpu;
    loadModels = ["qwen2.5:1b"];
  };
}
