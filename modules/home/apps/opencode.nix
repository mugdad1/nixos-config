# opencode + its local-model wiring — RESTORED 2026-11-06.
#
# HISTORY, because this file has died twice. It was created 2026-11-01
# (aa09df9), last good at d007234 (2026-11-02, "make opencode's local models
# use shell instead of Code Mode"), then DELETED by dac5544 ("f", 2026-11-03)
# alongside the old ollama.nix. The next day's squash to a single root commit
# (a468362) hid even the history — `git fetch --unshallow` brought it back and
# this file was rebuilt from `git show d007234:modules/home/apps/opencode.nix`.
# modules/core/packages.nix has pointed at this path the whole time; the
# package is fleet-wide, this is the config half, and they move together.
#
# The PACKAGE is in modules/core/packages.nix (`opencode`, restored
# 2026-11-01). This file is the other half: the config that points it at the
# local Ollama on victus, plus the SearXNG search wiring added 2026-11-06.
#
# WHAT THE JSON DOES:
#   model "ollama/mimo-v2.6:latest"
#     The only model on the box (hosts/victus/ollama.nix loadModels). The
#     old qwen3.5:4b / 2b / nemotron entries are gone with the models.
#   providers.ollama.models."mimo-v2.6:latest".limit.context = 16384
#     THE INVARIANT: this MUST equal OLLAMA_CONTEXT_LENGTH in
#     hosts/victus/ollama.nix. Ollama alone would get this wrong both ways —
#     its VRAM-based default is 4096 (journalctl: "vram-based default
#     context total_vram=3.7 GiB default_num_ctx=4096"), while the model
#     file advertises 262144 (qwen35.context_length), which cannot run on a
#     4 GiB card. opencode believing 262144 means it packs prompts past what
#     Ollama serves and the context is truncated mid-session. 16384 is the
#     rig-sized number: q8 KV ≈ 1.2 GB of the 3.7 GiB, weights6.6 GB split
#     CPU/GPU. Raise both sides together, never one.
#   capabilities.tools = true
#     `ollama show mimo-v2.6` reports completion/vision/tools/thinking;
#     stated so a future Ollama that stops reporting it does not silently
#     drop the tool list. vision is real — there is a 456M clip projector.
#   reasoning_effort: deliberately NOT set.
#     mimo thinks by default (levels false,true / default true). The old
#     qwen needed body.reasoning_effort = "none" to stop a 4B burning 9m50s
#     on thinking; mimo's thinking has been usable in practice. If a session
#     feels slow, that line is the first thing to try — untested on this
#     model, remove it again if the endpoint rejects it.
#
# permissions — the execute deny, WHY IT IS STILL HERE (2026-11-06):
#   opencode advertises two ways to run a command: `shell`, and `execute`
#   (Code Mode — a JavaScript sandbox that calls tools from inside JS). A
#   small model sees both, picks `execute`, and fills it with a shell-shaped
#   call:
#     {"command": "ls -la"}        what a 2b/9B sends
#     -> Invalid arguments for tool "execute": - code: Missing key
#   It retries the same wrong shape until the step budget runs out, then
#   tells the user "I can't run shell commands". Reproducible: 2b did it
#   five times in a row; mimo-v2.6 did it AGAIN on 2026-11-06 in the session
#   that prompted this restore. Denying `execute` removes Code Mode, and
#   every tool reachable only through it, from the tool list — the model
#   then has exactly one way to run a command and one way to edit. Proven
#   after the change (2026-11-02): qwen3.5:2b "run the cmd ls" -> shell,
#   correct output; qwen3.5:4b write/edit tasks correct. If a cloud model
#   is ever connected it loses Code Mode too; re-enable by scoping the deny
#   to an agent instead of the root `permissions`.
#
# WEB SEARCH — the 2026-11-06 addition, replacing what the old file called
# "a separate change, not this file":
#   opencode's BUILT-IN websearch tool cannot use SearXNG. It accepts only
#   Exa, Firecrawl, Parallel, Tavily or TinyFish, each needing an API key
#   (opencode auth list: none), so it is switched off below — leaving it on
#   is what lets a model hallucinate a nonexistent `WebSearch()` tool.
#   SearXNG instead enters as an MCP server: the house instance on grandpa
#   (hosts/grandpa/searxng.nix, :8888, search.formats includes json —
#   verified answering over the tailnet) behind mcp-searxng (npm, needs
#   Node 22+; nixpkgs nodejs from terminal/cli.nix is 24).
#   `codemode: false` is MANDATORY, not cosmetic: the execute deny above
#   would otherwise hide these tools too (they would only be reachable
#   through Code Mode). With it, the tools land directly on the model's
#   list as searxng_searxng_web_search, searxng_web_url_read, … and the
#   default base policy (allow *) means no permission prompts.
{pkgs, ...}: {
  xdg.configFile."opencode/opencode.json".text = ''
    {
      "$schema": "https://opencode.ai/config.json",
      "model": "ollama/mimo-v2.6:latest",
      "websearch": false,
      "permissions": [
        {"action": "execute", "resource": "*", "effect": "deny"}
      ],
      "mcp": {
        "servers": {
          "searxng": {
            "type": "local",
            "command": ["${pkgs.nodejs}/bin/npx", "-y", "mcp-searxng"],
            "environment": {
              "SEARXNG_URL": "http://100.106.116.60:8888"
            },
            "codemode": false
          }
        }
      },
      "providers": {
        "ollama": {
          "models": {
            "mimo-v2.6:latest": {
              "name": "MiMo V2.6 9B (local)",
              "limit": {
                "context": 16384,
                "output": 8192
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

  # Global instructions. Short on purpose: a small model follows five bullets,
  # not a style guide. These are the behaviours that actually failed in
  # practice — picking the wrong tool, describing a call instead of making
  # it, refusing a task the tool list already allows, and inventing tool
  # names (WebSearch) that do not exist. The search bullet points at the
  # searxng MCP tools that now exist.
  xdg.configFile."opencode/AGENTS.md".text = ''
    # Tool use

    - Run commands with the `shell` tool. Set `workdir` instead of `cd`.
    - Find paths with `glob`, find text with `grep`, then read with `read`.
    - Change files with `edit` for a focused change, `write` for a new file or
      a full replacement. You are able to edit files; never say you cannot.
    - Search the web with the `searxng` tools (searxng_web_search, and
      searxng_web_url_read to read one result). Never invent a tool name
      like WebSearch — if a tool is not in your list, it does not exist.
    - Call the tool. Do not describe the call you would make or ask whether to
      make it.
    - After changing something, run the command that proves it worked
      (`cat FILE`, the test, the build) and report the real output.
  '';
}
