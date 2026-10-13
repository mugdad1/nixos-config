# ─── DISABLED 2026-10-13 on his word ──────────────────────────────────────────
# Rust toolchain + oxalica/rust-overlay. He does not use Rust, so this whole
# module is a no-op now — it is still imported by modules/core/default.nix
# (scanPaths sweeps every .nix in core/), so it must stay a VALID module, just
# an empty one. Commented out, not deleted: uncomment the body to re-enable.
#
# What this was pulling in, and why it was worth disabling:
#   rust-bin.fromRustupToolchainFile  -> rustc + cargo + std, ~1 GB alone
#   the rust-overlay input            -> the overlay that provides rust-bin
#
# The cargo-* / rust tooling in modules/home/dev.nix (lines 57-79) and the
# `cargo` on PATH in modules/home/lazyvim.nix are ALSO commented out — they are
# separate packages that only make sense alongside a toolchain.
{...}: {}
#
# {
#   inputs,
#   pkgs,
#   ...
# }: {
#   nixpkgs.overlays = [
#     inputs.rust-overlay.overlays.default
#   ];
#
#   environment.systemPackages = with pkgs; [
#     (rust-bin.fromRustupToolchainFile ../../rust-toolchain.toml)
#   ];
# }
