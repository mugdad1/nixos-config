{pkgs, ...}: {
  security = {
    sudo = {
      enable = true;
      wheelNeedsPassword = true;
    };
    polkit = {
      enable = true;
      extraConfig = ''
        polkit.addRule(function(action, subject) {
          if (subject.isInGroup("wheel"))
            return polkit.Result.YES;
        });
      '';
    };
    rtkit.enable = true;

    pam.services.hyprlock = {};
  };
}
