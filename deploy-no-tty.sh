#!/bin/bash

# No-TTY Deployment Wrapper for Krea Speed Test Server
# This script ensures deployment works in any environment without TTY issues
# Usage: ./deploy-no-tty.sh <domain> [email]

set -e

# Force all non-interactive settings immediately
export DOCKER_NONINTERACTIVE=1
export DEBIAN_FRONTEND=noninteractive
export FORCE_NO_TTY=true

# Redirect stdin to prevent any TTY prompts
exec < /dev/null

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

# Check if deploy.sh exists
if [[ ! -f "deploy.sh" ]]; then
    log_error "deploy.sh not found in current directory"
    log_error "Please run this script from the speed-test-server directory"
    exit 1
fi

# Validate arguments
if [[ -z "$1" ]]; then
    log_error "Usage: $0 <domain> [email]"
    log_error "Example: $0 speedtest.example.com admin@example.com"
    exit 1
fi

DOMAIN="$1"
EMAIL="${2:-admin@${DOMAIN}}"

log_info "🚀 Starting No-TTY Deployment for Krea Speed Test Server"
log_info "Domain: $DOMAIN"
log_info "Email: $EMAIL"
log_info "Mode: Non-interactive (TTY disabled)"

# Set environment variables for non-interactive mode
export DOCKER_NONINTERACTIVE=1
export DEBIAN_FRONTEND=noninteractive

# Run deployment with --no-tty flag
log_info "Executing deployment script..."
./deploy.sh --no-tty "$DOMAIN" "$EMAIL"

log_success "🎉 No-TTY deployment completed successfully!"
log_info "Your speed test server is now running at: https://$DOMAIN"
