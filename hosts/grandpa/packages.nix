# Headless CLI set for grandpa. The desktop package lists live in modules/home
# and are not imported here.
{pkgs, ...}: {
  environment.systemPackages = with pkgs; [
    # Baseline
    curl
    dnsutils
    jq
    lm_sensors
    ripgrep
    rsync
    tmux
    vim

    # Health sweep (shared script; sections that do not apply say so)
    (writeShellScriptBin "checkup" (builtins.readFile ../../scripts/checkup.sh))

    # `ac` — one command for the AC. writeShellApplication pins its runtime
    # deps and runs shellcheck at build time.
    (writeShellApplication {
      name = "ac";
      runtimeInputs = [curl python3];
      text = builtins.readFile ../../scripts/grandpa/ac.sh;
    })

    # Asked for by name
    gh
    git

    # Filen + sops are grandpa-only: the laptops hold no age key.
    (pkgs.callPackage ../../pkgs/filen-cli.nix {})
    sops

    # python3 with the AC/serial libraries used for dongle probing.
    (python3.withPackages (p: [p.pyserial p.aioesphomeapi]))

    # Agent tooling: node for the study repo's tests, tcpdump for network debug.
    nodejs
    tcpdump
    (writeShellScriptBin "mcli" (builtins.readFile ../../scripts/mcli.sh))

    # CLI, headless-useful subset
    binutils
    duf
    dust
    entr
    eza
    fd
    file
    glow
    killall
    just
    ncdu
    neovim
    p7zip
    ripgrep-all
    socat
    strace
    tealdeer
    tree
    unzip
    wget
    zip

    # USB/serial probing for the Midea dongle
    picocom
    usbutils

    # Box admin: hardware and disks
    btop
    gptfdisk
    hdparm
    htop
    inxi
    iotop
    lazygit
    lsof
    mtr
    parted
    smartmontools
    traceroute

    sqlite
  ];
}
