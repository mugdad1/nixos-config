{
  inputs,
  pkgs,
  ...
}: let
  c = (import ../gruvbox.nix).raw;
in {
  imports = [inputs.zen-browser.homeModules.beta];

  programs.zen-browser = {
    enable = true;
    setAsDefaultBrowser = true;

    policies = {
      DisableAppUpdate = true;
      DisableTelemetry = true;
      DisableFirefoxStudies = true;
      DisablePocket = true;
      DisableFeedbackCommands = true;
      DontCheckDefaultBrowser = true;

      AIControls = {
        Default = {
          Value = "blocked";
          Locked = true;
        };
      };
      NoDefaultBookmarks = true;
      OfferToSaveLogins = false;

      EnableTrackingProtection = {
        Value = true;
        Locked = true;
        Cryptomining = true;
        Fingerprinting = true;
      };

      ExtensionSettings = {
        "uBlock0@raymondhill.net" = {
          install_url = "https://addons.mozilla.org/en-US/firefox/downloads/latest/ublock-origin/latest.xpi";
          installation_mode = "normal_installed";
        };
      };
    };

    profiles.default = {
      id = 0;
      isDefault = true;
      settings = {
        "toolkit.legacyUserProfileCustomizations.stylesheets" = true;
        "zen.theme.accent-color" = "#${c.green}";
        "zen.welcome-screen.seen" = true;

        "datareporting.healthreport.uploadEnabled" = false;
        "datareporting.policy.dataSubmissionEnabled" = false;
        "toolkit.telemetry.unified" = false;
        "toolkit.telemetry.enabled" = false;
        "toolkit.telemetry.archive.enabled" = false;
        "toolkit.telemetry.bhrPing.enabled" = false;
        "toolkit.telemetry.firstShutdownPing.enabled" = false;
        "toolkit.telemetry.hybridContent.enabled" = false;
        "toolkit.telemetry.newProfilePing.enabled" = false;
        "toolkit.telemetry.reportingpolicy.firstRun" = false;
        "toolkit.telemetry.shutdownPingSender.enabled" = false;
        "toolkit.telemetry.updatePing.enabled" = false;
        "browser.newtabpage.activity-stream.feeds.telemetry" = false;
        "browser.newtabpage.activity-stream.telemetry" = false;
        "browser.ping-centre.telemetry" = false;
        "browser.tabs.crashReporting.sendReport" = false;
        "browser.crashReports.unsubmittedCheck.enabled" = false;
        "app.shield.optoutstudies.enabled" = false;
        "app.normandy.enabled" = false;
        "beacon.enabled" = false;
        "breakpad.reportURL" = "";
        "captivedetect.canonicalURL" = "";
        "network.allow-experiments" = false;

        "dom.security.https_only_mode" = true;
        "dom.security.https_only_mode_ever_enabled" = true;
        "network.dns.disablePrefetch" = true;
        "network.prefetch-next" = false;
        "network.predictor.enabled" = false;
        "network.http.referer.XOriginPolicy" = 2;
        "network.http.referer.XOriginTrimmingPolicy" = 2;
        "privacy.trackingprotection.enabled" = true;
        "privacy.trackingprotection.socialtracking.enabled" = true;
        "privacy.trackingprotection.cryptomining.enabled" = true;
        "privacy.trackingprotection.fingerprinting.enabled" = true;
        "privacy.firstparty.isolate" = true;
        "media.peerconnection.ice.default_address_only" = true;
        "geo.enabled" = false;
        "browser.send_pings" = false;
        "dom.battery.enabled" = false;
        "media.autoplay.default" = 5;
        "media.autoplay.blocking_policy" = 2;
      };
      search = {
        default = "ddg";
        force = true;
      };

      userChrome = let
        c = (import ../gruvbox.nix).css;
      in
        with c; ''
          :root {
            --zen-main-browser-background: ${bg0_h} !important;
            --zen-colors-primary: ${green} !important;
            --zen-colors-secondary: ${blue} !important;
            --zen-colors-tertiary: ${purple} !important;
            --zen-colors-border: ${light_gray} !important;
            --toolbar-bgcolor: ${bg0} !important;
            --toolbar-color: ${fg} !important;
            --toolbar-field-background-color: ${bg0_h} !important;
            --toolbar-field-color: ${fg} !important;
            --toolbar-field-border-color: ${bg3} !important;
            --toolbar-field-focus: ${bg0_h} !important;
            --tab-selected-bg: ${bg1} !important;
            --tab-hover-bg: ${bg0} !important;
            --tab-loading-fill: ${green} !important;
            --lwt-accent-color: ${bg0_h} !important;
            --lwt-text-color: ${fg0} !important;
            --lwt-selected-tab-background-color: ${bg1} !important;
            --arrowpanel-background: ${bg0} !important;
            --arrowpanel-color: ${fg} !important;
            --arrowpanel-border-color: ${bg3} !important;
            --panel-background: ${bg0} !important;
            --panel-color: ${fg} !important;
            --panel-border-color: ${bg3} !important;
            --autocomplete-popup-background: ${bg0_h} !important;
            --autocomplete-popup-color: ${fg} !important;
            --sidebar-background: ${bg0_h} !important;
            --sidebar-text: ${fg} !important;
            --urlbar-background-color: ${bg0_h} !important;
            --urlbar-placeholder-color: ${light_gray} !important;
            --urlbar-view-bottom-border-color: ${green} !important;
            --chrome-content-separator-color: ${bg1} !important;
            --chrome-secondary-background-color: ${bg0} !important;
            --button-bgcolor: ${bg1} !important;
            --button-hover-bgcolor: ${bg2} !important;
            --button-active-bgcolor: ${bg3} !important;
            --button-color: ${fg} !important;
            --button-primary-bgcolor: ${green} !important;
            --button-primary-hover-bgcolor: ${bright_green} !important;
            --button-primary-color: ${bg0_h} !important;
            --checkbox-checked-bgcolor: ${green} !important;
            --checkbox-unchecked-bgcolor: ${bg1} !important;
            --focus-outline-color: ${green} !important;
            --input-bgcolor: ${bg0_h} !important;
            --input-color: ${fg} !important;
            --input-border-color: ${bg3} !important;
            --newtab-background-color: ${bg0_h} !important;
            --newtab-text-primary-color: ${fg0} !important;
            --newtab-element-hover-color: ${bg0} !important;
            --newtab-element-active-color: ${bg1} !important;
            --newtab-wordmark-color: ${fg} !important;
            --newtab-topsites-background-color: ${bg0} !important;
            --newtab-topsites-label-color: ${fg} !important;
            --newtab-search-background-color: ${bg0_h} !important;
            --newtab-search-border-color: ${bg3} !important;
            --newtab-search-icon-color: ${light_gray} !important;
            --download-progress-fill-color: ${green} !important;
            --download-progress-pause-color: ${yellow} !important;
            --download-progress-cancel-color: ${red} !important;
            --toolbarbutton-icon-fill: ${fg} !important;
            --toolbarbutton-icon-fill-attention: ${green} !important;
            --toolbarbutton-hover-background: ${bg1} !important;
            --toolbarbutton-active-background: ${bg2} !important;
            --tab-line-color: ${green} !important;
            --tab-attention-icon-color: ${green} !important;
            --tab-background-separator: ${bg1} !important;
            --tabs-border-color: ${bg1} !important;
            --panel-shortcut-color: ${fg2} !important;
            --panel-description-color: ${light_gray} !important;
            --sidebar-border-color: ${bg1} !important;
            --menu-background-color: ${bg0} !important;
            --menu-color: ${fg} !important;
            --menu-border-color: ${bg1} !important;
            --menu-disabled-color: ${dark_gray} !important;
            --menu-hover-background-color: ${bg1} !important;
            --menu-hover-color: ${fg0} !important;
            --menu-arrow-color: ${fg} !important;
            --menu-icon-color: ${gray} !important;
            --category-background-color-hover: ${bg1} !important;
            --category-text-color: ${fg} !important;
            --category-text-color-hover: ${fg0} !important;
            --category-text-color-active: ${green} !important;
            --card-background-color: ${bg0} !important;
            --card-color: ${fg} !important;
            --card-border-color: ${bg1} !important;
            --error-text-color: ${bright_red} !important;
            --warning-background-color: ${bg1} !important;
            --warning-color: ${yellow} !important;
            --warning-border-color: ${bg3} !important;
            --success-text-color: ${bright_green} !important;
            --info-text-color: ${bright_blue} !important;
            --in-content-page-background: ${bg0_h} !important;
            --in-content-page-color: ${fg} !important;
            --in-content-text-color: ${fg} !important;
            --in-content-selected-text: ${fg0} !important;
            --in-content-button-background: ${bg1} !important;
            --in-content-button-background-hover: ${bg2} !important;
            --in-content-button-background-active: ${bg3} !important;
            --in-content-primary-button-background: ${green} !important;
            --in-content-primary-button-background-hover: ${bright_green} !important;
            --in-content-primary-button-background-active: ${green} !important;
            --in-content-primary-button-text-color: ${bg0_h} !important;
            --in-content-link-color: ${blue} !important;
            --in-content-link-color-visited: ${purple} !important;
            --in-content-link-color-hover: ${bright_blue} !important;
            --in-content-link-color-active: ${bright_purple} !important;
            --in-content-table-background: ${bg0_h} !important;
            --in-content-table-border-color: ${bg1} !important;
            --in-content-table-header-background: ${green} !important;
            --in-content-table-header-color: ${bg0_h} !important;
            --in-content-box-background: ${bg0_h} !important;
            --in-content-box-background-hover: ${bg0} !important;
            --in-content-box-background-active: ${bg1} !important;
            --in-content-box-border-color: ${bg1} !important;
            --in-content-box-info-background: ${bg0} !important;
            --in-content-box-info-color: ${fg} !important;
            --in-content-warning-background: ${bg1} !important;
            --in-content-warning-color: ${yellow} !important;
            --in-content-warning-border-color: ${bg3} !important;
            --in-content-success-color: ${bright_green} !important;
          }
        '';
    };
  };
}
