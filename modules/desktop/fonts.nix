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
      # The Office/Vista set Word and PowerPoint default to (Calibri,
      # Cambria, Candara, Consolas, Corbel, Constantia). Without it those
      # names fall back to Public Sans / Noto Serif and documents reflow.
      vista-fonts
      # The whole Google Fonts library, so Canva/Word designs that name a
      # font by hand (Montserrat, Poppins, Oswald, …) render instead of
      # silently falling back.
      google-fonts
      # Arabic faces for Office documents: Amiri is the Naskh classic,
      # Scheherazade is what SIL/LaTeX use.
      amiri
      scheherazade-new

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
        src = ../../assets/fonts;
        installPhase = ''
          mkdir -p $out/share/fonts/truetype
          cp *.TTF $out/share/fonts/truetype/
        '';
      })
    ];
  };
}
