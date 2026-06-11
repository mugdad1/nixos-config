#!/bin/bash
set -e

WRAPPER_DIR="$HOME/.local/bin"
WRAPPER_PATH="$WRAPPER_DIR/asus-shutdown-wrapper"
ASUS_SHUTDOWN_BIN="$(command -v asus-shutdown)"

mkdir -p "$WRAPPER_DIR"

cat > "$WRAPPER_PATH" << EOF
#!/bin/sh
trap 'exit 0' TERM
exec $ASUS_SHUTDOWN_BIN
EOF

chmod +x "$WRAPPER_PATH"

if ! echo "$PATH" | grep -q "$WRAPPER_DIR"; then
    echo "export PATH=\"$WRAPPER_DIR:\$PATH\"" >> ~/.bashrc
    echo "export PATH=\"$WRAPPER_DIR:\$PATH\"" >> ~/.zshrc
fi

echo "asus-shutdown wrapper installed"
