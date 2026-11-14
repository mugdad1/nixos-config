# opencode's MCP servers and search policy. This lives in modules/core, not
# modules/home, because every host runs opencode (it is in
# modules/core/packages.nix) while only the desktops import the home stack —
# and the servers are the boxes with the services worth talking to.
#
# Nothing secret enters the store: the repository is public. Trilium's ETAPI
# token is read from a 0600 file at runtime and SearXNG needs no credential.
{
  pkgs,
  username,
  ...
}: let
  # SearXNG on grandpa, reached over the tailnet. The MCP server is a local
  # stdio process; referencing the store path here makes the home generation
  # keep it alive across garbage collection.
  searxngUrl = "http://100.106.116.60:8888";
in {
  home-manager.users.${username} = {
    xdg.configFile."opencode/opencode.json".text = builtins.toJSON {
      "$schema" = "https://opencode.ai/config.json";

      # The built-in search providers (exa, firecrawl, parallel, tavily,
      # tinyfish) are all third parties and none of them can point at a
      # SearXNG instance. Turning the tool off removes the choice: the agent
      # searches with the `searxng` MCP server below, which talks to grandpa
      # and nothing else. AGENTS.md below says so explicitly.
      websearch = false;

      mcp.servers = {
        # TriliumNext on asus. `oauth = false` is the important field: without
        # it opencode tries dynamic client registration against the endpoint,
        # which Trilium does not implement, and the connection dies with
        # "Router not found for request POST /register".
        trilium = {
          type = "remote";
          url = "http://100.92.54.61:8080/mcp";
          oauth = false;
          headers.Authorization = "Bearer {file:~/.config/trilium/etapi-token}";
        };

        searxng = {
          type = "local";
          command = ["${pkgs.mcp-searxng}/bin/mcp-searxng"];
          environment.SEARXNG_URL = searxngUrl;
        };
      };
    };

    # Global instructions, loaded by every session on every host. Kept short:
    # it exists to state the search policy, not to restate the tool list.
    home.file.".config/opencode/AGENTS.md".text = ''
      # Tool use

      - Web search: always use the `searxng_web_search` tool from the
        `searxng` MCP server, and read a result with `searxng_web_url_read`.
        The built-in search providers are disabled on purpose — do not ask to
        enable Exa, Tavily, Firecrawl, Parallel or TinyFish, and do not fall
        back to `curl` against a search engine.
      - The SearXNG instance is grandpa's (`${searxngUrl}`) over the tailnet.
        If it is down, say so instead of searching somewhere else.
      - Trilium notes live at `http://100.92.54.61:8080` (asus) and are
        available as the `trilium_*` tools. Use them for durable notes the
        user wants to keep; do not dump long text into the terminal.
    '';
  };
}
