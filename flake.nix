{
  description = "mugdad's nixos configuration";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    nix-flatpak.url = "github:gmodena/nix-flatpak";

    nixos-hardware.url = "github:NixOS/nixos-hardware";

    nix-index-database = {
      url = "github:nix-community/nix-index-database";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    zen-browser.url = "github:0xc000022070/zen-browser-flake/beta";

    rust-overlay.url = "github:oxalica/rust-overlay";
  };

  outputs = {nixpkgs, ...} @ inputs: let
    username = "mugdad";
    system = "x86_64-linux";
    mkHost = host: let
      variables = import ./hosts/${host}/variables.nix;
    in
      nixpkgs.lib.nixosSystem {
        modules = [
          ./hosts/${host}
        ];
        specialArgs = {
          inherit
            host
            inputs
            username
            variables
            ;
        };
      };
  in {
    formatter.${system} = nixpkgs.legacyPackages.${system}.alejandra;

    devShells.${system} = {
      default = nixpkgs.legacyPackages.${system}.mkShell {
        packages = with nixpkgs.legacyPackages.${system}; [
          alejandra
          statix
          deadnix
          shellcheck
          shfmt
          treefmt
          nixd
        ];
      };

      android = let
        unfreePkgs = import nixpkgs { inherit system; config = { allowUnfree = true; android_sdk.accept_license = true; }; };
        androidPkgs = unfreePkgs.androidenv;
        sdk = androidPkgs.composeAndroidPackages {
          platformVersions = [ "31" "35" "36" "37" ];
          abiVersions = [ "arm64-v8a" ];
          buildToolsVersions = [ "36.0.0" ];
          includeNDK = true;
          ndkVersion = "23.1.7779620";
          cmakeVersions = [ "3.22.1" ];
        };
      in unfreePkgs.mkShell {
        buildInputs = [
          sdk.androidsdk
          unfreePkgs.jdk21
          unfreePkgs.gradle
          unfreePkgs.nix
        ];
        shellHook = ''
          export NIX_SDK_STORE="${sdk.androidsdk}/libexec/android-sdk"
          export ANDROID_SDK_ROOT="$HOME/.android-sdk"
          export ANDROID_HOME="$ANDROID_SDK_ROOT"
          export JAVA_HOME="${unfreePkgs.jdk21}/lib/openjdk"
          export ANDROID_NDK_HOME="$ANDROID_SDK_ROOT/ndk/23.1.7779620"
          if [ ! -d "$ANDROID_SDK_ROOT" ]; then
            cp -rL "$NIX_SDK_STORE" "$ANDROID_SDK_ROOT"
            chmod -R u+w "$ANDROID_SDK_ROOT"
          fi
          export PATH="$ANDROID_SDK_ROOT/cmdline-tools/latest/bin:$ANDROID_SDK_ROOT/platform-tools:$PATH"
          echo "Android SDK: $ANDROID_SDK_ROOT"
          echo "Android NDK: $ANDROID_NDK_HOME"
        '';
      };
    };

    nixosConfigurations = {
      t480s = mkHost "t480s";
    };
  };
}
