# opencode's local-model wiring, victus only.
#
# The PACKAGE is fleet-wide in modules/core/packages.nix. This file is the
# config half: it points the CLI at the Ollama server on this host and at the
# house SearXNG on grandpa. t480s imports modules/home too but runs no Ollama,
# so the guard leaves it on opencode's defaults.
#
# TWO NUMBERS MUST MATCH: limit.context here and OLLAMA_CONTEXT_LENGTH in
# hosts/victus/default.nix (16384 on both). Ollama's own default is 4096,
# which silently truncates opencode's prompt; the model file advertises
# 262144, which cannot run on a 4 GB card. Raise both together or neither.
#
# The execute deny is deliberate: opencode offers `shell` and `execute` (Code
# Mode), small models pick `execute` and fill it with a shell-shaped call
# (`{"command": "ls"}` -> Missing key "code"), then claim they cannot run
# commands. Denying execute leaves exactly one way to run a command.
#
# Web search: opencode's built-in provider list is Exa/Firecrawl/Parallel/
# Tavily/TinyFish and none is configured, so `websearch` is false — otherwise
# the model hallucinates a `WebSearch` tool. SearXNG arrives as an MCP server
# instead, with `codemode: false` so its tools stay on the native tool list
# (the execute deny would otherwise hide them). Tool names are prefixed with
# the server name: searxng_searxng_web_search, searxng_web_url_read.
{
  host,
  lib,
  pkgs,
  ...
}: let
  searxng = "http://100.106.116.60:8888";

  # Every model gets the same context cap so switching models cannot silently
  # advertise the 262144 the model files claim.
  localModel = {
    name,
    image ? true,
    thinking ? false,
  }:
    {
      inherit name;
      limit = {
        context = 16384;
        output = 8192;
      };
      capabilities = {
        tools = true;
        input = ["text"] ++ lib.optional image "image";
        output = ["text"];
      };
    }
    // lib.optionalAttrs thinking {
      body.reasoning_effort = "none";
    };
in
  lib.mkIf (host == "victus") {
    xdg.configFile."opencode/opencode.json".text = builtins.toJSON {
      "$schema" = "https://opencode.ai/config.json";
      model = "ollama/qwen3.5:4b";
      websearch = false;
      permissions = [
        {
          action = "execute";
          resource = "*";
          effect = "deny";
        }
      ];
      mcp.servers.searxng = {
        type = "local";
        command = ["${pkgs.nodejs}/bin/npx" "-y" "mcp-searxng"];
        environment.SEARXNG_URL = searxng;
        codemode = false;
      };
      providers.ollama.models = {
        "qwen3.5:4b" = localModel {
          name = "Qwen3.5 4B (local)";
          thinking = true;
        };
        "gemma4:e4b" = localModel {
          name = "Gemma 4 E4B (local)";
        };
      };
    };

    # Global instructions. Short on purpose: a 4B model follows a handful of
    # bullets, not a style guide. These are the failures seen in practice:
    # wrong tool, describing a call instead of making it, refusing a task the
    # tool list allows, and inventing a WebSearch tool that does not exist.
    xdg.configFile."opencode/AGENTS.md".text = ''
      # Tool use

      - Run commands with the `shell` tool. Set `workdir` instead of `cd`.
      - Find paths with `glob`, find text with `grep`, then read with `read`.
      - Change files with `edit` for a focused change, `write` for a new file
        or a full replacement. You are able to edit files; never say you cannot.
      - Search the web with `searxng_searxng_web_search`. Read a result page
        with `searxng_web_url_read` (exactly that name — do not add a second
        `searxng_`). Never invent a tool name like WebSearch — if a tool is
        not in your list, it does not exist.
      - Call the tool. Do not describe the call you would make or ask whether
        to make it.
      - After changing something, run the command that proves it worked
        (`cat FILE`, the test, the build) and report the real output.
    '';
  }
