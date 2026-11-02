# opencode + its local-model wiring.
#
# The PACKAGE is fleet-wide in modules/core/packages.nix (`opencode`, restored
# 2026-11-01). This file is the other half: the config that points it at the
# local Ollama on victus. A package without this block would discover Ollama
# anyway but advertise its 262144-token context, which is how you get a
# 200k-token prompt on a 4 GB card.
#
# The JSON is deliberately plain and tiny. What it does:
#   providers.ollama.models."qwen3.5:2b".limit.context = 32768
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
#   qwen3.5:4b (default 2026-11-02)
#     The model that actually fits the 4 GiB card. Same guardrails: 32k
#     advertised context (matching the server), thinking off. Replaces
#     nemotron-3.5-bolt:e4b, which is 7.2–7.9 GB and runs mostly on the CPU.
#   nemotron-3-nano:4b (A/B, 2026-11-02)
#     Text-only, 2.8 GB, tiny KV cache. Benchmarks say it is much faster than
#     the 4b Qwen; it is listed so it can be selected in opencode and compared
#     on the Victus, not as the default (it once hallucinated tool names).
#
# WHY LOCAL MODELS "CAN'T USE SHELL" (2026-11-02)
#   opencode advertises two ways to run a command: `shell`, and `execute`
#   (Code Mode — a JavaScript sandbox that calls tools from inside JS). A small
#   model sees both, picks `execute`, and fills it with a shell-shaped call:
#     {"command": "ls -la"}        what 2b sends
#     -> Invalid arguments for tool "execute": - code: Missing key
#   It retries the same wrong shape until the step budget runs out, then tells
#   the user "I can't run shell commands" / "I can't edit files". This is
#   reproducible: 2b did it five times in a row on "run the cmd ls".
#   `permissions` below denies `execute` for every model. Denying it removes
#   Code Mode, and every tool reachable only through it, from the tool list —
#   so the model has exactly one way to run a command and one way to edit.
#   Re-measured after the change, 2026-11-02:
#     qwen3.5:2b  "run the cmd ls"          -> shell, correct output
#     qwen3.5:4b  "create notes.md"         -> write, file on disk
#     qwen3.5:4b  "append a line to it"     -> read + edit, diff correct
#   If a cloud model is ever connected, it loses Code Mode too; re-enable by
#   scoping the deny to an agent instead of the root `permissions`.
#
# Web search is NOT wired here: opencode's websearch tool needs one of Exa,
# Tavily, Firecrawl, Parallel or TinyFish, and none is configured. The house
# SearXNG on grandpa answers /search?format=json and can be exposed as an MCP
# tool instead — that is a separate change, not this file.
{...}: {
  xdg.configFile."opencode/opencode.json".text = ''
    {
      "$schema": "https://opencode.ai/config.json",
      "model": "ollama/qwen3.5:4b",
      "permissions": [
        {"action": "execute", "resource": "*", "effect": "deny"}
      ],
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
            "nemotron-3-nano:4b": {
              "name": "Nemotron 3 Nano 4B (local, A/B)",
              "limit": {
                "context": 32768,
                "output": 8192
              },
              "body": {
                "reasoning_effort": "none"
              },
              "capabilities": {
                "tools": true,
                "input": ["text"],
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

  # Global instructions. Short on purpose: a 4B model follows five bullets, not
  # a style guide. These are the behaviours that actually failed in practice —
  # picking the wrong tool, describing a call instead of making it, and
  # refusing a task the tool list already allows ("I can't edit files").
  xdg.configFile."opencode/AGENTS.md".text = ''
    # Tool use

    - Run commands with the `shell` tool. Set `workdir` instead of `cd`.
    - Find paths with `glob`, find text with `grep`, then read with `read`.
    - Change files with `edit` for a focused change, `write` for a new file or
      a full replacement. You are able to edit files; never say you cannot.
    - Call the tool. Do not describe the call you would make or ask whether to
      make it.
    - After changing something, run the command that proves it worked
      (`cat FILE`, the test, the build) and report the real output.
  '';
}
