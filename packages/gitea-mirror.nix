# gitea-mirror (RayLabsHQ/gitea-mirror, rev 0759db8) built from source with our
# own nixpkgs — no upstream flake, no multi-arch eval, no darwin.
#
# Strategy (the buildNpmPackage pattern, adapted for bun):
#   1. nodeModules  — fixed-output derivation that runs `bun install
#      --frozen-lockfile` once (network allowed only inside fixed-output
#      derivations), so the real (sandboxed, offline) build below is hermetic.
#   2. app          — copies that node_modules and runs `bun run build`
#      offline, then installs the SSR bundle + upstream entrypoint script.
{
  lib,
  stdenv,
  fetchFromGitHub,
  bun,
  openssl,
  gnused,
}: let
  src = fetchFromGitHub {
    owner = "RayLabsHQ";
    repo = "gitea-mirror";
    rev = "0759db80d3b7aa55b84b00c4e7f3fc6c23d7f914";
    sha256 = "sha256-t21op5pwWdBajyC6dqvKg/HeKIebQtuApTnrQ/aeh5k=";
  };

  nodeModules = stdenv.mkDerivation {
    pname = "gitea-mirror-node-modules";
    version = "1";
    src = src;
    nativeBuildInputs = [bun];
    dontConfigure = true;
    dontBuild = true;
    dontFixup = true;
    installPhase = ''
      runHook preInstall
      export HOME=$TMPDIR
      mkdir -p $out
      cp package.json bun.lock bunfig.toml $out/ 2>/dev/null || true
      cd $out
      bun install --frozen-lockfile --no-progress
      chmod -R u+w $out
      runHook postInstall
    '';
    outputHashMode = "recursive";
    outputHashAlgo = "sha256";
    outputHash = "sha256-50HHef78QfnB2seVEvl5xZdD+qpfDmvd5Oz6jvRpMcI=";
  };
in
  stdenv.mkDerivation {
    pname = "gitea-mirror";
    version = "3.14.1";
    src = src;
    nativeBuildInputs = [bun];

    buildPhase = ''
      runHook preBuild
      export HOME=$TMPDIR
      rm -rf node_modules
      cp -r ${nodeModules}/node_modules node_modules
      chmod -R u+w node_modules
      # The package.json "build" script is `bunx --bun astro build`; `bunx`
      # probes the registry even for a locally-resolvable binary and dies
      # silently in the offline sandbox. Run astro directly via bun instead.
      bun node_modules/astro/bin/astro.mjs build
      runHook postBuild
    '';

    installPhase = ''
            runHook preInstall
            mkdir -p $out/lib/gitea-mirror $out/bin
            cp -r dist node_modules scripts src drizzle package.json tsconfig.json $out/lib/gitea-mirror/

            cat > $out/bin/gitea-mirror <<'EOF'
      #!/bin/bash
      set -e

      # === DEFAULT CONFIGURATION ===
      # These match the upstream Docker defaults.
      export DATA_DIR=''${DATA_DIR:-"$HOME/.local/share/gitea-mirror"}
      export DATABASE_URL=''${DATABASE_URL:-"file:$DATA_DIR/gitea-mirror.db"}
      export HOST=''${HOST:-"0.0.0.0"}
      export PORT=''${PORT:-"4321"}
      export NODE_ENV=''${NODE_ENV:-"production"}

      # Better Auth configuration
      export BETTER_AUTH_URL=''${BETTER_AUTH_URL:-"http://localhost:4321"}
      export BETTER_AUTH_TRUSTED_ORIGINS=''${BETTER_AUTH_TRUSTED_ORIGINS:-"http://localhost:4321"}
      export PUBLIC_BETTER_AUTH_URL=''${PUBLIC_BETTER_AUTH_URL:-"http://localhost:4321"}

      # Concurrency settings (match docker-compose.alt.yml)
      export MIRROR_ISSUE_CONCURRENCY=''${MIRROR_ISSUE_CONCURRENCY:-3}
      export MIRROR_PULL_REQUEST_CONCURRENCY=''${MIRROR_PULL_REQUEST_CONCURRENCY:-5}

      # Create data directory
      mkdir -p "$DATA_DIR"
      SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
      APP_DIR="$SCRIPT_DIR/../lib/gitea-mirror"

      # The app uses process.cwd()/data for the database, but the Nix store
      # is read-only. Create a writable working directory with symlinks to
      # the app files and a real data directory.
      WORK_DIR="$DATA_DIR/.workdir"
      mkdir -p "$WORK_DIR"
      for item in dist node_modules scripts src drizzle package.json tsconfig.json; do
        ln -sfn "$APP_DIR/$item" "$WORK_DIR/$item"
      done
      ln -sfn "$DATA_DIR" "$WORK_DIR/data"
      cd "$WORK_DIR"

      # === AUTO-GENERATE SECRETS ===
      BETTER_AUTH_SECRET_FILE="$DATA_DIR/.better_auth_secret"
      ENCRYPTION_SECRET_FILE="$DATA_DIR/.encryption_secret"

      # Generate BETTER_AUTH_SECRET if not provided
      if [ -z "$BETTER_AUTH_SECRET" ]; then
        if [ -f "$BETTER_AUTH_SECRET_FILE" ]; then
          echo "Using previously generated BETTER_AUTH_SECRET"
          export BETTER_AUTH_SECRET=$(cat "$BETTER_AUTH_SECRET_FILE")
        else
          echo "Generating a secure random BETTER_AUTH_SECRET"
          GENERATED_SECRET=$(${openssl}/bin/openssl rand -hex 32)
          export BETTER_AUTH_SECRET="$GENERATED_SECRET"
          echo "$GENERATED_SECRET" > "$BETTER_AUTH_SECRET_FILE"
          chmod 600 "$BETTER_AUTH_SECRET_FILE"
          echo "BETTER_AUTH_SECRET generated and saved to $BETTER_AUTH_SECRET_FILE"
        fi
      fi

      # Generate ENCRYPTION_SECRET if not provided
      if [ -z "$ENCRYPTION_SECRET" ]; then
        if [ -f "$ENCRYPTION_SECRET_FILE" ]; then
          echo "Using previously generated ENCRYPTION_SECRET"
          export ENCRYPTION_SECRET=$(cat "$ENCRYPTION_SECRET_FILE")
        else
          echo "Generating a secure random ENCRYPTION_SECRET"
          GENERATED_ENCRYPTION_SECRET=$(${openssl}/bin/openssl rand -base64 36)
          export ENCRYPTION_SECRET="$GENERATED_ENCRYPTION_SECRET"
          echo "$GENERATED_ENCRYPTION_SECRET" > "$ENCRYPTION_SECRET_FILE"
          chmod 600 "$ENCRYPTION_SECRET_FILE"
          echo "ENCRYPTION_SECRET generated and saved to $ENCRYPTION_SECRET_FILE"
        fi
      fi

      # === DATABASE INITIALIZATION ===
      DB_PATH=$(echo "$DATABASE_URL" | ${gnused}/bin/sed 's|^file:||')
      if [ ! -f "$DB_PATH" ]; then
        echo "Database not found. It will be created and initialized on first startup..."
        touch "$DB_PATH"
      else
        echo "Database already exists, Drizzle will check for pending migrations on startup..."
      fi

      # === STARTUP SCRIPTS ===
      echo "Checking for environment configuration..."
      if [ -f "scripts/startup-env-config.ts" ]; then
        echo "Loading configuration from environment variables..."
        ${bun}/bin/bun scripts/startup-env-config.ts && \
          echo "Environment configuration loaded successfully" || \
          echo "Environment configuration loading completed with warnings"
      fi

      echo "Running startup recovery..."
      if [ -f "scripts/startup-recovery.ts" ]; then
        ${bun}/bin/bun scripts/startup-recovery.ts --timeout=30000 && \
          echo "Startup recovery completed successfully" || \
          echo "Startup recovery completed with warnings"
      fi

      echo "Running repository status repair..."
      if [ -f "scripts/repair-mirrored-repos.ts" ]; then
        ${bun}/bin/bun scripts/repair-mirrored-repos.ts --startup && \
          echo "Repository status repair completed successfully" || \
          echo "Repository status repair completed with warnings"
      fi

      # === SIGNAL HANDLING ===
      shutdown_handler() {
        echo "Received shutdown signal, forwarding to application..."
        if [ ! -z "$APP_PID" ]; then
          kill -TERM "$APP_PID" 2>/dev/null || true
          wait "$APP_PID" 2>/dev/null || true
        fi
        exit 0
      }

      trap 'shutdown_handler' TERM INT HUP

      # === START APPLICATION ===
      echo "Starting Gitea Mirror..."
      echo "Access the web interface at $BETTER_AUTH_URL"
      ${bun}/bin/bun dist/server/entry.mjs &
      APP_PID=$!

      wait "$APP_PID"
      EOF
            chmod +x $out/bin/gitea-mirror
            runHook postInstall
    '';

    meta = with lib; {
      description = "Self-hosted GitHub to Gitea mirroring service";
      homepage = "https://github.com/RayLabsHQ/gitea-mirror";
      license = licenses.mit;
      mainProgram = "gitea-mirror";
    };
  }
  // {
    passthru.nodeModules = nodeModules;
  }
