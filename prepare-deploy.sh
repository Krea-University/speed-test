#!/bin/bash

# Krea Speed Test Server - Deployment Preparation Script
# This script prepares the application for deployment

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

prepare_deployment() {
    log_info "🚀 Preparing Krea Speed Test Server for Deployment"
    echo "=================================================="
    
    # Build the application
    log_info "Building application..."
    make build
    
    # Create deployment package
    log_info "Creating deployment package..."
    
    # Create temporary deployment directory
    DEPLOY_DIR="/tmp/speed-test-server"
    rm -rf "$DEPLOY_DIR"
    mkdir -p "$DEPLOY_DIR"
    
    # Copy necessary files
    cp -r . "$DEPLOY_DIR/"
    
    # Remove unnecessary files from deployment package
    cd "$DEPLOY_DIR"
    rm -rf .git .gitignore README.md docs/
    
    # Ensure binary is present and executable
    if [[ ! -f "bin/speed-test-server" ]]; then
        log_error "Application binary not found. Please run 'make build' first."
        exit 1
    fi
    
    chmod +x bin/speed-test-server
    
    log_success "Deployment package prepared in $DEPLOY_DIR"
    
    # Display deployment instructions
    echo ""
    log_info "📋 DEPLOYMENT INSTRUCTIONS:"
    echo "=========================="
    echo ""
    echo "1. Copy the deployment package to your server:"
    echo "   scp -r $DEPLOY_DIR root@your-server:/tmp/"
    echo ""
    echo "2. SSH to your server and run the deployment script:"
    echo "   ssh root@your-server"
    echo "   cd /tmp/speed-test-server"
    echo "   ./deploy.sh your-domain.com admin@your-domain.com"
    echo ""
    echo "3. Example deployment command:"
    echo "   ./deploy.sh speedtest.example.com admin@example.com"
    echo ""
    log_warning "⚠️  Make sure your domain points to your server's IP address!"
    log_warning "⚠️  The deployment script must be run as root (use sudo)!"
    echo ""
    
    # Create a quick deployment script
    cat > deploy-quick.sh <<'EOF'
#!/bin/bash
# Quick deployment script - run this on your server

if [[ $# -lt 1 ]]; then
    echo "Usage: $0 <domain> [email]"
    echo "Example: $0 speedtest.example.com admin@example.com"
    exit 1
fi

# Check if running as root
if [[ $EUID -ne 0 ]]; then
    echo "This script must be run as root (use sudo)"
    exit 1
fi

# Run the main deployment script
./deploy.sh "$@"
EOF
    
    chmod +x deploy-quick.sh
    
    log_success "Quick deployment script created: deploy-quick.sh"
    echo ""
}

# Run preparation
prepare_deployment

echo -e "${GREEN}✅ Ready for deployment!${NC}"
