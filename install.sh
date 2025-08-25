#!/bin/bash

# Krea Speed Test Server - One-Command Installation Script
# Usage: curl -fsSL https://raw.githubusercontent.com/Krea-University/speed-test-server/main/install.sh | bash -s -- <domain> [email]

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
BOLD='\033[1m'
NC='\033[0m' # No Color

# Configuration
DOMAIN="$1"
EMAIL="${2:-admin@${DOMAIN}}"
REPO_URL="https://github.com/Krea-University/speed-test-server.git"
INSTALL_DIR="/tmp/speed-test-server"

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
                    Professional Speed Test Server
EOF
    echo -e "${NC}"
    echo -e "${GREEN}=============================================${NC}"
    echo -e "${GREEN}🚀 One-Command Installation & Deployment${NC}"
    echo -e "${GREEN}=============================================${NC}"
    echo ""
}

check_root() {
    if [[ $EUID -ne 0 ]]; then
        log_error "This script must be run as root"
        log_info "Please run: sudo $(basename $0) $*"
        exit 1
    fi
}

check_domain() {
    if [[ -z "$DOMAIN" ]]; then
        log_error "Usage: $0 <domain> [email]"
        log_error "Example: $0 speedtest.example.com admin@example.com"
        echo ""
        echo -e "${YELLOW}💡 Quick start examples:${NC}"
        echo "  curl -fsSL https://raw.githubusercontent.com/Krea-University/speed-test-server/main/install.sh | bash -s -- speedtest.yourdomain.com"
        echo "  curl -fsSL https://raw.githubusercontent.com/Krea-University/speed-test-server/main/install.sh | bash -s -- speedtest.yourdomain.com admin@yourdomain.com"
        exit 1
    fi
    
    log_info "🌐 Domain: $DOMAIN"
    log_info "📧 Email: $EMAIL"
}

check_prerequisites() {
    log_info "🔍 Checking prerequisites..."
    
    # Check operating system
    if ! command -v apt-get &> /dev/null && ! command -v yum &> /dev/null; then
        log_error "This script supports Ubuntu/Debian (apt) and CentOS/RHEL (yum) only"
        exit 1
    fi
    
    # Check internet connectivity
    if ! ping -c 1 google.com &> /dev/null; then
        log_error "No internet connection detected"
        exit 1
    fi
    
    # Check if domain resolves to this server
    SERVER_IP=$(curl -s ifconfig.me 2>/dev/null || curl -s ipinfo.io/ip 2>/dev/null || echo "unknown")
    DOMAIN_IP=$(dig +short "$DOMAIN" 2>/dev/null | head -n1)
    
    if [[ -n "$DOMAIN_IP" && "$DOMAIN_IP" != "$SERVER_IP" ]]; then
        log_warning "⚠️  Domain $DOMAIN resolves to $DOMAIN_IP but server IP is $SERVER_IP"
        log_warning "⚠️  Make sure your DNS A record points to this server"
        log_warning "⚠️  Continuing with deployment - please verify DNS settings after installation"
        sleep 2  # Brief pause to ensure user sees the warning
    fi
    
    log_success "✅ Prerequisites check passed"
}

install_dependencies() {
    log_info "📦 Installing dependencies..."
    
    # Detect OS and install dependencies
    if command -v apt-get &> /dev/null; then
        export DEBIAN_FRONTEND=noninteractive
        apt-get update -q
        apt-get install -y git curl wget unzip
    else
        yum update -y
        yum install -y git curl wget unzip
    fi
    
    log_success "✅ Dependencies installed"
}

download_source() {
    log_info "⬇️  Downloading Krea Speed Test Server..."
    
    # Remove existing directory
    rm -rf "$INSTALL_DIR"
    
    # Clone repository
    git clone "$REPO_URL" "$INSTALL_DIR"
    cd "$INSTALL_DIR"
    
    log_success "✅ Source code downloaded"
}

run_deployment() {
    log_info "🚀 Starting deployment..."
    
    # Make scripts executable
    chmod +x deploy.sh prepare-deploy.sh deployment-summary.sh
    
    # Run deployment
    ./deploy.sh "$DOMAIN" "$EMAIL"
    
    log_success "✅ Deployment completed successfully!"
}

display_completion() {
    echo ""
    echo -e "${BOLD}${GREEN}🎉 INSTALLATION COMPLETE! 🎉${NC}"
    echo -e "${GREEN}==============================${NC}"
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
    echo -e "${BLUE}🔧 Management:${NC}"
    echo -e "   Location: ${BOLD}/opt/speed-test-server/${NC}"
    echo -e "   Credentials: ${BOLD}/opt/speed-test-server/DEPLOYMENT_INFO.txt${NC}"
    echo ""
    echo -e "${YELLOW}⚠️  Important: Save your credentials from DEPLOYMENT_INFO.txt${NC}"
    echo ""
    echo -e "${BLUE}📋 Next Steps:${NC}"
    echo "   1. Test your application: curl https://$DOMAIN/healthz"
    echo "   2. View API docs: https://$DOMAIN/swagger/index.html"
    echo "   3. Check management scripts: cd /opt/speed-test-server && ls *.sh"
    echo "   4. View service status: cd /opt/speed-test-server && ./status.sh"
    echo ""
    echo -e "${GREEN}🏁 Installation completed successfully!${NC}"
    echo ""
    
    # Show credentials if available
    if [[ -f "/opt/speed-test-server/DEPLOYMENT_INFO.txt" ]]; then
        echo -e "${YELLOW}📄 Deployment Information:${NC}"
        echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        cat /opt/speed-test-server/DEPLOYMENT_INFO.txt
        echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    fi
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
