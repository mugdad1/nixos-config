{pkgs, ...}: {
  fonts = {
    fontconfig = {
      defaultFonts = {
        monospace = [
          "Iosevka Nerd Font"
          "JetBrainsMono Nerd Font"
        ];
        sansSerif = ["Public Sans"];
        serif = ["Noto Serif"];
        emoji = ["Noto Color Emoji"];
      };
    };

    packages = with pkgs; [
      nerd-fonts.iosevka

      noto-fonts
      public-sans

      nerd-fonts.jetbrains-mono
      nerd-fonts.symbols-only

      noto-fonts-color-emoji
      comic-relief
      corefonts

      fira
      fira-code
      fira-code-symbols
      cascadia-code
      source-sans
      source-serif
      source-code-pro
      inter
      roboto
      roboto-mono
      roboto-slab
      lato
      ubuntu-classic
      liberation_ttf
      freefont_ttf
      proggyfonts
      cantarell-fonts
      dejavu_fonts
      gyre-fonts
      font-awesome
      material-icons
      material-design-icons

      (pkgs.stdenv.mkDerivation {
        name = "century-schoolbook";
        src = ../../fonts;
        installPhase = ''
          mkdir -p $out/share/fonts/truetype
          cp *.TTF $out/share/fonts/truetype/
        '';
      })
    ];
  };
}
