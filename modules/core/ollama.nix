{pkgs, ...}: {
  services.ollama = {
    enable = true;
    package = pkgs.ollama-cpu;
    loadModels = ["llama3.2:1b"];
  };
}
