{
  lib,
  pkgs,
  config,
  ...
}: let
  defaultApps = {
    text = ["com.mitchellh.ghostty.desktop"];
    image = ["imv-dir.desktop"];
    audio = ["vlc.desktop"];
    video = ["vlc.desktop"];
    directory = ["nemo.desktop"];
    office = ["libreoffice.desktop"];
    pdf = ["org.gnome.Evince.desktop"];
    archive = ["org.gnome.FileRoller.desktop"];
  };

  mimeMap = {
    text = ["text/plain"];
    image = [
      "image/bmp"
      "image/gif"
      "image/jpeg"
      "image/jpg"
      "image/png"
      "image/svg+xml"
      "image/tiff"
      "image/vnd.microsoft.icon"
      "image/webp"
    ];
    audio = [
      "audio/aac"
      "audio/mpeg"
      "audio/ogg"
      "audio/opus"
      "audio/wav"
      "audio/webm"
      "audio/x-matroska"
    ];
    video = [
      "video/mp2t"
      "video/mp4"
      "video/mpeg"
      "video/ogg"
      "video/webm"
      "video/x-flv"
      "video/x-matroska"
      "video/x-msvideo"
    ];
    directory = ["inode/directory"];
    office = [
      "application/vnd.oasis.opendocument.text"
      "application/vnd.oasis.opendocument.spreadsheet"
      "application/vnd.oasis.opendocument.presentation"
      "application/vnd.openxmlformats-officedocument.wordprocessingml.document"
      "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet"
      "application/vnd.openxmlformats-officedocument.presentationml.presentation"
      "application/msword"
      "application/vnd.ms-excel"
      "application/vnd.ms-powerpoint"
      "application/rtf"
    ];
    pdf = ["application/pdf"];
    archive = [
      "application/zip"
      "application/rar"
      "application/7z"
      "application/*tar"
    ];
  };

  associations = builtins.listToAttrs (
    lib.lists.flatten (
      lib.attrsets.mapAttrsToList (key: map (type: lib.attrsets.nameValuePair type defaultApps."${key}")) mimeMap
    )
  );
in {
  xdg.mimeApps.enable = true;
  xdg.mimeApps.defaultApplications = associations;

  home.packages = with pkgs; [waypaper];

  home.file."Pictures/wallpapers/others".source = pkgs.symlinkJoin {
    name = "wallpapers-others";
    paths = [
      ../../wallpapers/otherWallpaper/gruvbox
      ../../wallpapers/otherWallpaper/nixos
    ];
  };

  xdg.configFile."waypaper/config.ini".text = ''
    [Settings]
    language = en
    folder = ${config.home.homeDirectory}/Pictures/wallpapers/others
    monitors = All
    wallpaper = ${config.home.homeDirectory}/Pictures/wallpapers/others/nixos.png
    backend = awww
    fill = fill
    sort = name
    color = #ffffff
    subfolders = False
    show_hidden = False
    show_gifs_only = False
    number_of_columns = 3
    awww_transition_type = any
    awww_transition_step = 90
    awww_transition_angle = 0
    awww_transition_duration = 2
    awww_transition_fps = 60
    use_xdg_state = False
  '';
}
