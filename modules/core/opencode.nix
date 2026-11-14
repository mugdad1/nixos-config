# opencode's MCP servers. This lives in modules/core, not modules/home,
# because every host runs opencode (it is in modules/core/packages.nix) while
# only the desktops import the home stack — and the servers are the boxes with
# the services worth talking to.
#
# Both entries are wired without secrets in the store: the repository is
# public. Trilium's ETAPI token is read from a 0600 file at runtime and
# SearXNG needs no credential at all.
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
  home-manager.users.${username}.xdg.configFile."opencode/opencode.json".text =
    builtins.toJSON {
      "$schema" = "https://opencode.ai/config.json";

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
}
