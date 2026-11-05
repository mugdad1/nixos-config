# The full ArtCraft / Craft Apps suite, laptops only.
#
# modules/desktop is imported by hosts/victus and hosts/t480s and NEVER by
# hosts/grandpa (headless server — his packages come via his host file and
# modules/core), so everything in here lands on the two laptops and nowhere
# else. Added 2026-11-05 at his request: "i want the full".
#
# Install route: the vendor's OCI flatpak remote (artcraft-oci,
# oci+https://getartcraft.com — GPGVerify=false, public preview repo, 302
# redirects to GitHub Releases with sha256 digests in the index). Chosen over
# nixpkgs on his call ("why use nixpkgs why not full in flatpak so it's
# consistent"): the nixpkgs rust builds are partial (9 of 16, cadcraft …
# wordcraft) and version-frozen, while the vendor repo carries 13 of 16 plus
# the ArtCraft Launcher — one mechanism, one update channel, matching the
# install instructions on getartcraft.com/linux. The global flatpak setup
# (wayland-forced sockets, !x11) already lives in ./flatpak.nix and applies
# unchanged.
#
# Verified against the live remote on 2026-11-05 via
# `flatpak remote-ls artcraft-oci` (refs listed as app/<id>/<arch>/stable).
# The repo currently serves exactly the 14 refs below and NOT
# `ai.storyteller.texturecraft`, `ai.storyteller.materialcraft` or
# `ai.storyteller.craft-anything`: their .flatpakref URLs exist on the site
# but `flatpak remote-info artcraft-oci <id>` answers "Can't find ref" for
# all three. Those are presumably early-access builds the ArtCraft Launcher
# pulls from elsewhere — if/when the repo starts serving them, add them to
# `packages` below. The launcher IS in the remote as
# ai.storyteller.artcraft-launcher (stable) — the same app the
# github.com/storytold/craft-launcher v0.13.0 release bundle ships — so it is
# installed from the remote like everything else instead of from the bundle,
# keeping one source and a single self-update path.
#
# nix-flatpak note: the module default `remotes` is [flathub] only, and our
# definition would REPLACE that default (lists don't merge across modules),
# so flathub is spelled out explicitly here alongside artcraft-oci.
{...}: {
  services.flatpak = {
    remotes = [
      {
        name = "flathub";
        location = "https://dl.flathub.org/repo/flathub.flatpakrepo";
      }
      {
        name = "artcraft-oci";
        location = "https://getartcraft.com/artcraft-oci.flatpakrepo";
      }
    ];

    packages =
      map (appId: {
        inherit appId;
        origin = "artcraft-oci";
      }) [
        # Meta-installer: provisions and updates the Craft Apps.
        "ai.storyteller.artcraft-launcher"
        # The thirteen Craft Apps the remote currently serves (verified 2026-11-05).
        "ai.storyteller.cadcraft"
        "ai.storyteller.deckcraft"
        "ai.storyteller.designcraft"
        "ai.storyteller.effectcraft"
        "ai.storyteller.figcraft"
        "ai.storyteller.filmcraft"
        "ai.storyteller.gridcraft"
        "ai.storyteller.lightcraft"
        "ai.storyteller.pdfcraft"
        "ai.storyteller.photocraft"
        "ai.storyteller.soundcraft"
        "ai.storyteller.vectorcraft"
        "ai.storyteller.wordcraft"
        # NOT SERVED by the remote yet (re-check and add when they appear):
        #   ai.storyteller.texturecraft
        #   ai.storyteller.materialcraft
        #   ai.storyteller.craft-anything
      ];
  };
}
