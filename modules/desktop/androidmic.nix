{pkgs, ...}: {
  # AndroidMic — use the phone as this machine's microphone.
  #   PC app:  https://github.com/teamclouday/AndroidMic (cloned at
  #            ~/projects/AndroidMic; nixpkgs ships the same version)
  #   Android: APK from releases, or F-Droid io.github.teamclouday.AndroidMic
  #
  # The phone streams audio in; the PC has to present that stream as a
  # microphone. That is what the null sink below is for — AndroidMic *plays*
  # into the sink, and the sink's monitor is what apps record *from*. Without
  # it the app can send audio all day and nothing will see a mic.
  environment.systemPackages = with pkgs; [
    android-mic # 2.2.10, same build as the cloned repo
  ];

  # The virtual audio cable, declared rather than `pactl load-module`-ed by
  # hand: those calls die with the PipeWire session and are exactly the kind of
  # thing that would not come back after a reinstall.
  #
  # Built through the adapter factory (the documented way to mint a null sink
  # in PipeWire) instead of PulseAudio's module-null-sink, so it is native to
  # the stack actually running here — pipewire + pipewire-pulse + wireplumber.
  services.pipewire.extraConfig.pipewire."50-androidmic" = {
    context.objects = [
      {
        factory = "adapter";
        adapter = {
          factory.name = "support.null-audio-sink";
          node.name = "androidmic";
          node.description = "AndroidMic";
          media.class = "Audio/Sink";
          # Stereo sink: the README asks for Mono in the *app's* settings on
          # Linux, which is a client-side choice and does not belong here.
          audio.position = "FL,FR";
          monitor.channel-volumes = true;
        };
      }
    ];
  };
}
