#!/bin/bash

# TTY Fix Script for Krea Speed Test Server
# This script helps resolve "the input device is not a TTY" errors

echo "🔧 TTY Fix Script for Krea Speed Test Server"
echo "=============================================="
echo ""

# Check if we're in the right directory
if [[ ! -f "docker-compose.yml" ]]; then
    echo "❌ Error: docker-compose.yml not found"
    echo "Please run this script from the speed-test-server directory"
    exit 1
fi

echo "🔍 Checking current TTY status..."
if [ -t 0 ]; then
    echo "✅ stdin is a terminal"
else
    echo "⚠️  stdin is not a terminal"
fi

if [ -t 1 ]; then
    echo "✅ stdout is a terminal"
else
    echo "⚠️  stdout is not a terminal"
fi

echo ""
echo "🛠️  Applying TTY fixes..."

# Set environment variable for non-interactive mode
export DOCKER_NONINTERACTIVE=1
echo "✅ Set DOCKER_NONINTERACTIVE=1"

# Add to bashrc for persistence
if ! grep -q "DOCKER_NONINTERACTIVE" ~/.bashrc; then
    echo "export DOCKER_NONINTERACTIVE=1" >> ~/.bashrc
    echo "✅ Added DOCKER_NONINTERACTIVE to ~/.bashrc"
fi

# Update management scripts to handle TTY better
echo "🔄 Updating management scripts..."

# Create a wrapper script for docker-compose exec
cat > docker-exec-wrapper.sh << 'EOF'
#!/bin/bash
# Wrapper for docker-compose exec with TTY handling
if [ -t 0 ] && [[ "${DOCKER_NONINTERACTIVE}" != "1" ]]; then
    docker-compose exec "$@"
else
    docker-compose exec -T "$@"
fi
EOF

chmod +x docker-exec-wrapper.sh
echo "✅ Created docker-exec-wrapper.sh"

echo ""
echo "🧪 Testing TTY detection..."
./docker-exec-wrapper.sh mysql echo "TTY test successful" 2>/dev/null || echo "Would use -T flag"

echo ""
echo "✅ TTY fixes applied successfully!"
echo ""
echo "📋 Next steps:"
echo "1. Try using the --no-tty flag: ./deploy.sh --no-tty yourdomain.com"
echo "2. Or use the no-TTY wrapper: ./deploy-no-tty.sh yourdomain.com"
echo "3. For individual scripts: ./backup-now.sh --no-tty"
echo "4. If still having issues, prepend commands with:"
echo "   DOCKER_NONINTERACTIVE=1 ./your-command.sh"
echo "5. Or use the wrapper: ./docker-exec-wrapper.sh <service> <command>"
echo ""
echo "🔗 For more help, see: https://github.com/Krea-University/speed-test-server#troubleshooting"
