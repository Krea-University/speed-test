#!/bin/bash

# Krea Speed Test Server - Completely TTY-Free Installation Script
# This script guarantees no TTY requirements and forces non-interactive mode
# Usage: curl -fsSL https://raw.githubusercontent.com/Krea-University/speed-test/main/install-no-tty.sh | bash -s -- <domain> [email]

set -e

# Force non-interactive mode globally from the start
export DOCKER_NONINTERACTIVE=1
export DEBIAN_FRONTEND=noninteractive
export FORCE_NO_TTY=true

# Configuration
DOMAIN="$1"
EMAIL="${2:-admin@${DOMAIN}}"
REPO_URL="https://github.com/Krea-University/speed-test.git"
INSTALL_DIR="/tmp/speed-test"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
BOLD='\033[1m'
NC='\033[0m' # No Color

# Functions
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

print_banner() {
    echo -e "${BOLD}${BLUE}"
    cat << 'EOF'
 _  __                   ____                     _   _____         _   
| |/ /_ __ ___  __ _    / ___| _ __   ___  ___  __| | |_   _|__  ___| |_ 
| ' /| '__/ _ \/ _` |   \___ \| '_ \ / _ \/ _ \/ _` |   | |/ _ \/ __| __|
| . \| | |  __/ (_| |    ___) | |_) |  __/  __/ (_| |   | |  __/\__ \ |_ 
|_|\_\_|  \___|\__,_|   |____/| .__/ \___|\___|\__,_|   |_|\___||___/\__|
                              |_|                                       
               TTY-Free Professional Speed Test Server
EOF
    echo -e "${NC}"
    echo -e "${GREEN}=============================================${NC}"
    echo -e "${GREEN}🚀 TTY-Free Installation & Deployment${NC}"
    echo -e "${GREEN}=============================================${NC}"
    echo ""
}

check_root() {
    if [[ $EUID -ne 0 ]]; then
        log_error "This script must be run as root"
        log_info "Please run: curl -fsSL https://raw.githubusercontent.com/Krea-University/speed-test/main/install-no-tty.sh | sudo bash -s -- yourdomain.com"
        exit 1
    fi
}

check_domain() {
    if [[ -z "$DOMAIN" ]]; then
        log_error "Usage: TTY-Free installer requires domain"
        log_error "Example: curl -fsSL https://raw.githubusercontent.com/Krea-University/speed-test/main/install-no-tty.sh | sudo bash -s -- speedtest.example.com"
        exit 1
    fi
    
    log_info "🌐 Domain: $DOMAIN"
    log_info "📧 Email: $EMAIL"
    log_info "🔧 Mode: TTY-Free (guaranteed non-interactive)"
}

check_prerequisites() {
    log_info "🔍 Checking prerequisites..."
    
    # Check operating system
    if ! command -v apt-get &> /dev/null && ! command -v yum &> /dev/null; then
        log_error "This script supports Ubuntu/Debian (apt) and CentOS/RHEL (yum) only"
        exit 1
    fi
    
    # Check internet connectivity
    if ! ping -c 1 -W 5 google.com &> /dev/null; then
        log_error "No internet connection detected"
        exit 1
    fi
    
    log_success "✅ Prerequisites check passed"
}

install_dependencies() {
    log_info "📦 Installing dependencies (non-interactive)..."
    
    # Detect OS and install dependencies
    if command -v apt-get &> /dev/null; then
        export DEBIAN_FRONTEND=noninteractive
        apt-get update -qq > /dev/null 2>&1
        apt-get install -y -qq git curl wget unzip > /dev/null 2>&1
    else
        yum update -y -q > /dev/null 2>&1
        yum install -y -q git curl wget unzip > /dev/null 2>&1
    fi
    
    log_success "✅ Dependencies installed"
}

download_source() {
    log_info "⬇️  Downloading Krea Speed Test Server..."
    
    # Remove existing directory
    rm -rf "$INSTALL_DIR"
    
    # Clone repository quietly
    git clone -q "$REPO_URL" "$INSTALL_DIR"
    cd "$INSTALL_DIR"
    
    log_success "✅ Source code downloaded"
}

run_deployment() {
    log_info "🚀 Starting TTY-free deployment..."
    
    # Make scripts executable
    chmod +x deploy.sh deploy-no-tty.sh fix-tty.sh 2>/dev/null || true
    chmod +x prepare-deploy.sh deployment-summary.sh 2>/dev/null || true
    
    # Always use the most TTY-safe method available
    if [[ -f "deploy-no-tty.sh" ]]; then
        log_info "Using deploy-no-tty.sh (dedicated TTY-free wrapper)..."
        ./deploy-no-tty.sh "$DOMAIN" "$EMAIL"
    else
        log_info "Using deploy.sh with forced --no-tty..."
        ./deploy.sh --no-tty "$DOMAIN" "$EMAIL"
    fi
    
    log_success "✅ TTY-free deployment completed successfully!"
}

display_completion() {
    echo ""
    echo -e "${BOLD}${GREEN}🎉 TTY-FREE INSTALLATION COMPLETE! 🎉${NC}"
    echo -e "${GREEN}======================================${NC}"
    echo ""
    echo -e "${BLUE}🌐 Your Speed Test Server is ready at:${NC}"
    echo -e "   ${BOLD}https://$DOMAIN${NC}"
    echo ""
    echo -e "${BLUE}📚 API Documentation:${NC}"
    echo -e "   ${BOLD}https://$DOMAIN/swagger/index.html${NC}"
    echo ""
    echo -e "${BLUE}💓 Health Check:${NC}"
    echo -e "   ${BOLD}https://$DOMAIN/healthz${NC}"
    echo ""
    echo -e "${GREEN}🏁 TTY-free installation completed successfully!${NC}"
}

cleanup() {
    log_info "🧹 Cleaning up temporary files..."
    rm -rf "$INSTALL_DIR"
}

main() {
    print_banner
    check_root
    check_domain
    check_prerequisites
    install_dependencies
    download_source
    run_deployment
    cleanup
    display_completion
}

# Handle interruption
trap 'log_error "Installation interrupted"; cleanup; exit 1' INT TERM

# Run main function
main "$@"
