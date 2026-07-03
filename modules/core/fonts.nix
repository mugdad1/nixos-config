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
    ];
  };
}
