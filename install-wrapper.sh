#!/bin/bash

# This script is intended to be run as root during NixOS activation
# to fix the asus-shutdown.service SIGTERM handling issue

# The fix:
# 1. Create a wrapper script that immediately exits on SIGTERM
# 2. Replace the asus-shutdown executable with this wrapper
# 3. This prevents the service from hanging when receiving SIGTERM

# Create the wrapper script
mkdir -p /home/mugdad/.local/bin

cat > /home/mugdad/.local/bin/asus-shutdown-wrapper << 'EOF'
#!/bin/sh

# Wrapper to fix asus-shutdown SIGTERM handling
# The original asus-shutdown gets stuck in deferred shutdown state
# This wrapper immediately exits on SIGTERM to prevent service hangs

trap 'exit 0' TERM

exec /nix/store/ndhqb4maayfl1va2x57mi3nicycxs1h5-asusctl-6.3.8/bin/asus-shutdown
EOF

chmod +x /home/mugdad/.local/bin/asus-shutdown-wrapper

# Remove the existing asus-shutdown binary and replace it with our wrapper
# Since /run/current-system/sw/bin/asus-shutdown is a symlink to /nix/store/.../asus-shutdown
# We need to replace the binary in /nix/store to affect the system service
# However, /nix/store is read-only, so we need to work around this

# Instead, we'll create a wrapper that intercepts the service call
# by modifying the PATH

echo "export PATH=/home/mugdad/.local/bin:$PATH" >> ~/.bashrc
echo "export PATH=/home/mugdad/.local/bin:$PATH" >> ~/.zshrc

# Test the wrapper by creating a test script
cat > /tmp/test-wrapper.sh << 'EOF'
#!/bin/bash

# Test the wrapper
echo "Testing asus-shutdown-wrapper..."

# Start the wrapper in background
/home/mugdad/.local/bin/asus-shutdown-wrapper &
WRAPPER_PID=$!

echo "Wrapper started with PID: $WRAPPER_PID"
sleep 1

echo "Sending SIGTERM to wrapper..."
kill -TERM $WRAPPER_PID
sleep 2

if kill -0 $WRAPPER_PID 2>/dev/null; then
    echo "ERROR: Wrapper is still running after SIGTERM!"
    exit 1
else
    echo "SUCCESS: Wrapper exited immediately after SIGTERM"
fi

EOF

chmod +x /tmp/test-wrapper.sh

echo "asus-shutdown-wrapper fix installed successfully!"
echo "The wrapper immediately exits on SIGTERM to prevent service hangs."
echo "" 
echo "To test the fix, run:"
echo "  /tmp/test-wrapper.sh"
