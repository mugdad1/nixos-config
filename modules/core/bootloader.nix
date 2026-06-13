{ pkgs, lib, ... }:

let
  splash = pkgs.runCommand "gruvbox-splash.bmp" {
    nativeBuildInputs = [ (pkgs.python3.withPackages (ps: [ ])) ];
  } ''
    python3 << 'PYEOF'
import struct
width, height = 1920, 1080
r, g, b = 0x1d, 0x20, 0x21
row_size = width * 3 + (4 - width * 3 % 4) % 4
pixels = b""
for y in range(height):
    pixels += bytes([b, g, r]) * width + b"\x00" * (row_size - width * 3)
fs = 54 + len(pixels)
hdr = b"BM" + struct.pack("<I", fs) + b"\x00\x00\x00\x00" + struct.pack("<I", 54)
dib = struct.pack("<I", 40) + struct.pack("<i", width) + struct.pack("<i", height)
dib += struct.pack("<H", 1) + struct.pack("<H", 24) + struct.pack("<I", 0)
dib += struct.pack("<I", len(pixels)) + struct.pack("<i", 2835) + struct.pack("<i", 2835)
dib += struct.pack("<I", 0) + struct.pack("<I", 0)
with open("$out", "wb") as f:
    f.write(hdr + dib + pixels)
PYEOF
  '';
in
{
  boot = {
    loader = {
      systemd-boot = {
        enable = true;
        consoleMode = "max";
        configurationLimit = 10;
        edk2-uefi-shell.enable = true;
        extraFiles = {
          "splash.bmp" = splash;
          "EFI/systemd/splash.bmp" = splash;
        };
      };
      efi.canTouchEfiVariables = true;
    };

    plymouth = {
      enable = true;
      theme = "spinner";
    };

    kernelParams = lib.mkBefore [
      "quiet"
      "splash"
    ];

    kernelPackages = pkgs.linuxPackages_latest;
    kernelModules = [ "hid-nintendo" ];
    supportedFilesystems = [ "ntfs" ];
  };
}
