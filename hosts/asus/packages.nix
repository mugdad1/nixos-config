# Headless CLI set for asus — mirrors hosts/grandpa/packages.nix so the two
# servers carry the same tools. modules/home (which supplies the desktop
# package lists) is not imported on either box.
#
# Dropped from the grandpa list because they are tied to that machine:
#   ac          — the Midea AC dongle lives next to grandpa
#   filen-cli   — grandpa's cloud account, no age key on the laptops
#   sops        — same
#   python3 + pyserial/aioesphomeapi, picocom — the dongle probe stack
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

    # Asked for by name
    gh
    git

    # Agent tooling: tcpdump for network debug.
    tcpdump

    # hosts/asus/study.nix runs scripts/serve.py (stdlib only, but it is python).
    python3
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

    # USB probing
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
