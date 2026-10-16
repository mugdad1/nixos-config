{
  # Defaulted to the same account name as the other two hosts ("copy from
  # thinkcentre"). It is a ONE-LINE change until the box is installed — nothing
  # references /home yet — but a rename AFTER install is the /home/void ->
  # /home/mugdad shape that took a whole pass to unwind on the ThinkCentre
  # (decisions.md row 78). So if it should be something grandpa-specific, say so
  # before install day.
  username = "mugdad";
  timezone = "Asia/Riyadh";
  locale = "en_US.UTF-8";

  gitUser = "mugdad1";
  gitEmail = "mugdad02@tutamail.com";

  # NOTE: no browser / terminal / launcher / keyboardLayout fields, ON PURPOSE.
  # Those are read by modules/home (sway, waybar, rofi) and modules/core/user.nix
  # imports that stack only when `variables ? browser`. This host is headless, so
  # it declares none and gets none. Do not add them "for shape parity" — same
  # note as hosts/thinkcentre/variables.nix.
}
