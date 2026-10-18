# THE MD SERVICE — grandpa renders ~/projects/wiki to HTML and nginx serves it.
#
# His word, 2026-10-18: *"i love md files"* — so nothing changes hands: the md
# files stay md files in git (GitHub stays the source of truth), grandpa only
# RENDERS them. A timer pulls the repo and rebuilds, so a `git push` shows up on
# the site within 15 minutes without touching anything manually.
#
# Why here and not the thinkcentre: grandpa's role was the open question until
# today ("which services it runs is still the open question" in default.nix).
# It gained Forgejo this same day (gitea was rm'd from the thinkcentre on his
# word) and this is the second half of what he wanted hosted: the wiki.
#
# PRIVACY, stated once and enforced by the build: `private/`, `archive/` and
# `AGENTS.md` are in `exclude_docs`, so those pages are never written to the
# docroot — curling the private path 404s. Everything else in the repo is meant
# to be readable (the repo itself is public).
{pkgs, ...}: let
  docsDir = "/home/mugdad/projects/wiki";
  siteDir = "/var/lib/wiki/site";

  # mkdocs + the material theme in one env, so the CLI on PATH in the unit
  # below is the exact set that was tested here — not whatever the system
  # happens to carry.
  mkdocsEnv = pkgs.python3.withPackages (ps: with ps; [mkdocs mkdocs-material]);

  # The config lives in the Nix store: one declaration, and a rebuild is what
  # changes it. docs_dir/site_dir are absolute, which mkdocs resolves as-is
  # (os.path.join with an absolute second argument keeps it).
  mkdocsCfg = pkgs.writeText "wiki-mkdocs.yml" ''
    site_name: mugdad — wiki
    site_description: decisions, goals and logs, rendered from git
    docs_dir: ${docsDir}
    site_dir: ${siteDir}
    theme:
      name: material
      language: en
      features:
        - navigation.sections
        - search.highlight
        - content.code.copy
    # gitignore-style paths, relative to docs_dir. private/ and archive/ are
    # excluded from the BUILD, not just the nav — they never reach the docroot.
    exclude_docs: |
      private/
      archive/
      AGENTS.md
    markdown_extensions:
      # decisions.md is ALL tables — without this the whole log renders as
      # literal pipe characters. This is the extension that matters most here.
      - tables
      - toc:
          permalink: true
      - admonition
      - attr_list
      - fenced_code
  '';
in {
  # tmpfiles first: the unit runs as mugdad, and mugdad cannot mkdir under
  # /var/lib itself. Owner mugdad so the build can write; 0755 so the nginx
  # user can read. The site/ subdir inside is created by mkdocs.
  systemd.tmpfiles.rules = [
    "d /var/lib/wiki 0755 mugdad users -"
  ];

  # pull + build. Oneshot, driven by the timer below (and by hand):
  #   sudo systemctl start wiki-build
  systemd.services.wiki-build = {
    description = "git pull + mkdocs build of ~/projects/wiki";
    after = ["network-online.target"];
    wants = ["network-online.target"];
    serviceConfig = {
      Type = "oneshot";
      User = "mugdad";
      Group = "users";
      WorkingDirectory = docsDir;
    };
    environment.HOME = "/home/mugdad";
    # git, ssh (the remote is git@github.com — grandpa's key already auths, it
    # cloned this repo today) and the mkdocs CLI itself.
    path = [pkgs.git pkgs.openssh mkdocsEnv];
    script = ''
      set -eu
      # pull-first, ff-only: a local edit on grandpa must never be clobbered
      # and never pushed back — this box only ever READS the repo.
      if git pull --ff-only -q; then
        echo "wiki: pulled $(git rev-parse --short HEAD)"
      else
        echo "wiki: pull not clean — building what is already on disk"
      fi
      ${mkdocsEnv}/bin/mkdocs build --clean --config-file ${mkdocsCfg}
      echo "wiki: built to ${siteDir}"
    '';
  };

  systemd.timers.wiki-build = {
    wantedBy = ["timers.target"];
    timerConfig = {
      OnBootSec = "2min";
      # measured cadence: the repo changes a few times a day, 15 min keeps the
      # site honest without waking the spinning disk every minute.
      OnUnitActiveSec = "15min";
      Persistent = true;
    };
  };

  services.nginx = {
    enable = true;
    virtualHosts.wiki = {
      # catch-all: this box serves nothing else, so any Host header lands here
      # and http://192.168.8.254/ just works.
      default = true;
      root = siteDir;
      extraConfig = "index index.html;";
    };
  };

  # nginx :80 — merges with the [ 3000 ] that default.nix declares for forgejo;
  # allowedTCPPorts is a list option, so the two modules add up.
  networking.firewall.allowedTCPPorts = [80];
}
