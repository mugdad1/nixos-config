# The full ArtCraft / Craft Apps suite, laptops only, installed from the
# vendor's OCI flatpak remote. The global flatpak socket policy lives in
# ./flatpak.nix and applies unchanged.
_: {
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
        # Not served by the remote yet: texturecraft, materialcraft,
        # craft-anything. Add them when `flatpak remote-info` finds the ref.
      ];
  };
}
