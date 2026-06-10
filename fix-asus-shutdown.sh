#!/bin/bash

# Fix for asus-shutdown.service SIGTERM handling
# This script is intended to be run during NixOS activation

# Create the wrapper script
mkdir -p /home/mugdad/.local/bin

cat > /home/mugdad/.local/bin/asus-shutdown-wrapper << 'EOF'
#!/bin/sh

# Wrapper to fix asus-shutdown SIGTERM handling
# The original asus-shutdown gets stuck in deferred shutdown state
# This wrapper immediately exits on SIGTERM to prevent service hangs

trap 'exit 0' TERM

exec /nix/store/idwc6axhwl2ddpdyb8pv2n8g0k2rkinb-asusctl-6.3.7/bin/asus-shutdown
EOF

chmod +x /home/mugdad/.local/bin/asus-shutdown-wrapper

# Add to PATH so it can be found
if ! echo "$PATH" | grep -q "/home/mugdad/.local/bin"; then
    echo "export PATH=/home/mugdad/.local/bin:\$PATH" >> ~/.bashrc
    echo "export PATH=/home/mugdad/.local/bin:\$PATH" >> ~/.zshrc
fi

echo "asus-shutdown wrapper installed"
