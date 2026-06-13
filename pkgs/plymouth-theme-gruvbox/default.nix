{ pkgs, lib, ... }:

let
  themeName = "gruvbox";
in
pkgs.stdenv.mkDerivation {
  pname = "plymouth-theme-${themeName}";
  version = "1.0";

  src = lib.cleanSourceWith {
    filter = name: type: lib.hasSuffix ".plymouth" name;
    src = ./.;
  };

  nativeBuildInputs = with pkgs; [ imagemagick python3 ];

  buildPhase = ''
    mkdir -p $out/share/plymouth/themes/${themeName}

    cp gruvbox.plymouth $out/share/plymouth/themes/${themeName}/

    python3 << 'PYEOF'
import math, subprocess, os

out = os.environ['out']
theme = "gruvbox"
dest = f"{out}/share/plymouth/themes/{theme}"

size = 64
cx, cy = 32, 32
radius = 22
dot_r = 3
n_dots = 12
n_frames = 30

for frame in range(n_frames):
    cmd = ["convert", "-size", f"{size}x{size}", "xc:none"]
    for dot in range(n_dots):
        angle = 2 * math.pi * dot / n_dots - math.pi / 2
        x = cx + radius * math.cos(angle)
        y = cy + radius * math.sin(angle)

        shift = int(frame * n_dots / n_frames)
        offset = (dot + shift) % n_dots

        if offset < 3:
            color = '#fabd2f'
        elif offset < 6:
            color = '#d65d0e'
        else:
            color = '#504945'

        cmd.extend(["-fill", color, "-draw", f"circle {x:.1f},{y:.1f} {x+dot_r:.1f},{y:.1f}"])

    cmd.append(f"{dest}/throbber-{frame + 1:04d}.png")
    subprocess.run(cmd, check=True)

# bullet.png — unselected bullet (Gruvbox gray)
bullet_size = 12
b_cx = bullet_size // 2
b_r = 4
subprocess.run([
    "convert", "-size", f"{bullet_size}x{bullet_size}", "xc:none",
    "-fill", "#504945", "-draw", f"circle {b_cx},{b_cx} {b_cx + b_r},{b_cx}",
    f"{dest}/bullet.png"
], check=True)

# entry.png — selected entry (Gruvbox yellow)
subprocess.run([
    "convert", "-size", f"{bullet_size}x{bullet_size}", "xc:none",
    "-fill", "#fabd2f", "-draw", f"circle {b_cx},{b_cx} {b_cx + b_r},{b_cx}",
    f"{dest}/entry.png"
], check=True)

# lock.png — simple padlock (Gruvbox fg)
subprocess.run([
    "convert", "-size", "32x32", "xc:none",
    "-fill", "#ebdbb2",
    "-draw", "roundrectangle 6,14 26,30 4,4",
    "-draw", "roundrectangle 12,4 20,14 4,4",
    "-fill", "#1d2021",
    "-draw", "circle 16,20 16,24",
    f"{dest}/lock.png"
], check=True)

# capslock.png — triangle indicator (Gruvbox fg)
subprocess.run([
    "convert", "-size", "32x32", "xc:none",
    "-fill", "#ebdbb2", "-draw", "polygon 16,4 28,26 4,26",
    f"{dest}/capslock.png"
], check=True)

# keyboard.png — simple keyboard icon (Gruvbox fg)
subprocess.run([
    "convert", "-size", "32x20", "xc:none",
    "-fill", "#ebdbb2",
    "-draw", "roundrectangle 0,0 32,20 3,3",
    "-fill", "#1d2021",
    "-draw", "rectangle 4,6 28,8",
    "-draw", "rectangle 6,12 12,14",
    "-draw", "rectangle 16,12 22,14",
    f"{dest}/keyboard.png"
], check=True)

# keymap-render.png — simplified keyboard layout
subprocess.run([
    "convert", "-size", "48x32", "xc:none",
    "-fill", "#ebdbb2",
    "-draw", "rectangle 0,0 48,32",
    "-fill", "#1d2021",
    "-draw", "rectangle 2,2 46,10",
    "-draw", "rectangle 2,14 22,22",
    "-draw", "rectangle 26,14 46,22",
    f"{dest}/keymap-render.png"
], check=True)
PYEOF
  '';

  installPhase = "true";
}
