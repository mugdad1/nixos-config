{pkgs, ...}: {
  # AndroidMic — use the phone as this machine's microphone.
  #   PC app:  https://github.com/teamclouday/AndroidMic (cloned at
  #            ~/projects/AndroidMic; nixpkgs ships the same version)
  #   Android: APK from releases, or F-Droid io.github.teamclouday.AndroidMic
  #
  # The phone streams audio in; the PC has to present that stream as a
  # microphone. That is the null sink below — AndroidMic *plays* into it, and
  # its monitor is what apps record *from*. Without it the app can send audio
  # all day and nothing sees a mic.
  environment.systemPackages = with pkgs; [
    android-mic # 2.2.10, same build as the cloned repo
    pulseaudio # pactl, used by the service below to create the sink
  ];

  # udev rule so the app can reach the phone over raw USB (its "USB" mode
  # talks to the device through libusb, not through adb).
  #
  # Without this the app reports "no usb device connected" even with the
  # cable firmly in — libusb gets EACCES on the device node. The kernel
  # attaches no driver here, so 70-uaccess.rules never tags it and the
  # logged-in user has no business opening it. TAG+="uaccess" hands the node
  # to whoever is logged in on the seat, via logind's ACLs — no group to join,
  # no MODE="0666" widening it for everyone.
  #
  # 22d9 is the OnePlus/OPPO vendor id as enumerated on this box (OnePlus 7T
  # Pro, HD1911, product 2765). Matched on vendor only: the id changes when
  # the phone flips into accessory mode, and the rule has to hold across that
  # transition or the connect drops halfway.
  services.udev.extraRules = ''
    # AndroidMic — allow the logged-in seat user raw USB access to the phone
    SUBSYSTEM=="usb", ATTR{idVendor}=="22d9", TAG+="uaccess"
  '';

  # NOTE why this is a service and not `services.pipewire.extraConfig`.
  # The obvious declarative route is a `context.objects` drop-in in
  # /etc/pipewire/pipewire.conf.d, and it does not work. PipeWire loads a
  # drop-in as *filename = section, content = object to merge* — its own debug
  # log on this box reads:
  #     loaded config '.../pipewire.conf.d/context.objects.conf' with 0 items
  #     loaded config '.../pipewire.conf.d/context.properties.conf' with 1 items
  # context.properties is an object, so it merges. context.objects is an
  # *array*, so a bare array parses to 0 items and is silently discarded.
  # Proven, not assumed: the sink was absent across two rebuilds that both
  # produced a byte-correct file.
  #
  # So the sink is created at session start instead. Still declarative — it
  # comes back after a reinstall with everything else, which is the part that
  # actually matters. The commands are the README's, verified working against
  # this box's pipewire-pulse before being written here.
  systemd.user.services.androidmic-virtual-mic = {
    description = "AndroidMic virtual microphone (null sink + monitor source)";
    after = ["pipewire-pulse.service" "wireplumber.service"];
    requires = ["pipewire-pulse.service"];
    wantedBy = ["default.target"];

    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
      ExecStart = pkgs.writeShellScript "androidmic-virtual-mic" ''
        set -eu
        PATH="${pkgs.pulseaudio}/bin:${pkgs.gnugrep}/bin:${pkgs.coreutils}/bin"

        if ! pactl list short sources | grep -q androidmic_source; then
          id=$(pactl load-module module-null-sink \
                  sink_name=androidmic \
                  sink_properties=device.description=AndroidMic)
          pactl load-module module-remap-source \
                  master=androidmic.monitor source_name=androidmic_source \
                  source_properties=device.description=AndroidMicMic
          echo "created virtual mic (sink module $id)"
        else
          echo "virtual mic already present"
        fi
      '';
      ExecStop = pkgs.writeShellScript "androidmic-virtual-mic-stop" ''
        set -u
        PATH="${pkgs.pulseaudio}/bin:${pkgs.coreutils}/bin"
        for m in $(pactl list short modules | grep -E "remap-source|null-sink" | grep -E "androidmic" | cut -f1); do
          pactl unload-module "$m" || true
        done
      '';
    };
  };
}
