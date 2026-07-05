rec {
  css = import ../../gruvbox.nix;
  font = "Iosevka Nerd Font";
  font_size = "18px";
  font_weight = "bold";
  text_color = css.css.fg0;
  background_1 = css.css.bg0;
  border_color = css.css.light_gray;
  red = css.css.red;
  green = css.css.green;
  yellow = css.css.bright_yellow;
  blue = css.css.blue;
  cyan = css.css.aqua;
  orange_bright = css.css.bright_orange;
  opacity = "1";
}
