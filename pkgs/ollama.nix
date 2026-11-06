# Ollama, built from the latest upstream GitHub release.
#
# WHY NOT `pkgs.ollama-cuda`: the locked nixos-unstable trails upstream (it
# carried v0.40.13 while MiMo V2.6 needed v0.40.15), and waiting for nixpkgs to
# package a new release is not what "mcli update" should do. This reuses
# nixpkgs' CUDA build recipe but takes the ollama tag, the llama.cpp pin from
# that tag's LLAMA_CPP_VERSION, and both hashes from `pkgs/ollama-pins.nix`.
#
# `mcli update` runs scripts/update-ollama.sh before rebuilding. That script
# asks GitHub for the latest release, rewrites the four pins above, and lets
# the normal build proceed; there is no manual version bump.
#
# Once nixpkgs catches up, the guard below returns `ollama-cuda` untouched and
# the pin stops mattering — though the updater will keep the file current
# either way.
#
# The prebuilt release tarball is the alternative. It is 1.44 GiB and its
# llama.cpp runners are linked against a generic glibc; building the same
# source through the nixpkgs recipe keeps the CUDA runtime patched for NixOS
# (autoAddDriverRunpath) and lands in the binary cache when it can.
{
  lib,
  fetchFromGitHub,
  ollama-cuda,
}: let
  pins = import ./ollama-pins.nix;

  pinned = ollama-cuda.overrideAttrs (old: {
    inherit (pins) version vendorHash;

    src = fetchFromGitHub {
      owner = "ollama";
      repo = "ollama";
      tag = "v${pins.version}";
      hash = pins.srcHash;
    };

    # postPatch reads these from finalAttrs.passthru, so replacing the passthru
    # entry is what actually points the build at the pinned llama.cpp.
    passthru =
      old.passthru
      // {
        inherit (pins) llamaCppVersion;
        llamaCppSrc = fetchFromGitHub {
          owner = "ggml-org";
          repo = "llama.cpp";
          tag = pins.llamaCppVersion;
          hash = pins.llamaCppHash;
        };
      };
  });
in
  if lib.versionAtLeast ollama-cuda.version pins.version
  then ollama-cuda
  else pinned
