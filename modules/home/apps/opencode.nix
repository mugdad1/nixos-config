# opencode + its local-model wiring.
#
# The PACKAGE is fleet-wide in modules/core/packages.nix (`opencode`, restored
# 2026-11-01). This file is the other half: the config that points it at the
# local Ollama on victus. A package without this block would discover Ollama
# anyway but advertise its 262144-token context, which is how you get a
# 200k-token prompt on a 4 GB card.
#
# The JSON is deliberately plain and tiny. What it does:
#   providers.ollama.models."qwen3.5:4b".limit.context = 32768
#     Overrides the context Ollama reports (262144) with the 32k the server is
#     actually configured for in hosts/victus/ollama.nix. The two numbers MUST
#     match; if you raise one, raise the other (OLLAMA_CONTEXT_LENGTH).
#   capabilities.tools = true
#     Ollama reports this already; stated so a future Ollama that stops
#     reporting it does not silently drop the tool list.
#   body.reasoning_effort = "none"
#     THE BIG ONE. qwen3.5 thinks by default, and a 4B on a 4 GB card
#     generates at ~6 tok/s — the same write-a-file task took 9m50s with
#     thinking on and 24s with it off. Ollama's OpenAI endpoint ignores
#     "think": false; "reasoning_effort": "none" is what actually switches it
#     off. Measured 2026-11-01. Remove this line when a faster box makes
#     thinking affordable, not before.
#
# Web search is NOT wired here: opencode's websearch tool needs one of Exa,
# Tavily, Firecrawl, Parallel or TinyFish, and none is configured. The house
# SearXNG on grandpa answers /search?format=json and can be exposed as an MCP
# tool instead — that is a separate change, not this file.
{...}: {
  xdg.configFile."opencode/opencode.json".text = ''
    {
      "$schema": "https://opencode.ai/config.json",
      "providers": {
        "ollama": {
          "models": {
            "qwen3.5:4b": {
              "name": "Qwen3.5 4B (local)",
              "limit": {
                "context": 32768,
                "output": 8192
              },
              "body": {
                "reasoning_effort": "none"
              },
              "capabilities": {
                "tools": true,
                "input": ["text", "image"],
                "output": ["text"]
              }
            },
            "qwen3.5:2b": {
              "name": "Qwen3.5 2B (local, fast)",
              "limit": {
                "context": 32768,
                "output": 8192
              },
              "body": {
                "reasoning_effort": "none"
              },
              "capabilities": {
                "tools": true,
                "input": ["text", "image"],
                "output": ["text"]
              }
            }
          }
        }
      }
    }
  '';
}
