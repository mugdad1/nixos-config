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
