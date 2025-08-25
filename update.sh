#!/bin/bash

# Krea Speed Test Server - Update Script
# Usage: ./update.sh [--force] [--branch=branch_name]

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
BOLD='\033[1m'
NC='\033[0m' # No Color

# Configuration
REPO_URL="https://github.com/Krea-University/speed-test-server.git"
APP_DIR="/opt/speed-test-server"
BACKUP_DIR="/opt/speed-test-server-backup-$(date +%Y%m%d_%H%M%S)"
TEMP_DIR="/tmp/speed-test-server-update"
FORCE_UPDATE=false
BRANCH="main"

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --force)
            FORCE_UPDATE=true
            shift
            ;;
        --branch=*)
            BRANCH="${1#*=}"
            shift
            ;;
        -h|--help)
            echo "Usage: $0 [--force] [--branch=branch_name]"
            echo "  --force    : Skip version check and force update"
            echo "  --branch   : Specify git branch (default: main)"
            echo "  --help     : Show this help message"
            exit 0
            ;;
        *)
            echo "Unknown option: $1"
            exit 1
            ;;
    esac
done

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
                         UPDATE MANAGER
EOF
    echo -e "${NC}"
    echo -e "${GREEN}=============================================${NC}"
    echo -e "${GREEN}🔄 Speed Test Server Update Tool${NC}"
    echo -e "${GREEN}=============================================${NC}"
    echo ""
}

check_root() {
    if [[ $EUID -ne 0 ]]; then
        log_error "This script must be run as root"
        log_info "Please run: sudo $0 $*"
        exit 1
    fi
}

check_installation() {
    log_info "🔍 Checking current installation..."
    
    if [[ ! -d "$APP_DIR" ]]; then
        log_error "Speed Test Server not found at $APP_DIR"
        log_error "Please run the installation script first"
        exit 1
    fi
    
    if [[ ! -f "$APP_DIR/docker-compose.yml" ]]; then
        log_error "Docker Compose file not found. Invalid installation."
        exit 1
    fi
    
    log_success "✅ Current installation found"
}

get_current_version() {
    log_info "📋 Getting current version..."
    
    cd "$APP_DIR"
    
    if [[ -d ".git" ]]; then
        CURRENT_COMMIT=$(git rev-parse HEAD 2>/dev/null || echo "unknown")
        CURRENT_BRANCH=$(git branch --show-current 2>/dev/null || echo "unknown")
        log_info "Current commit: ${CURRENT_COMMIT:0:8}"
        log_info "Current branch: $CURRENT_BRANCH"
    else
        log_warning "Not a git repository. Cannot determine current version."
        CURRENT_COMMIT="unknown"
    fi
}

check_for_updates() {
    log_info "🔍 Checking for updates..."
    
    # Clone latest version to temp directory
    rm -rf "$TEMP_DIR"
    git clone --branch "$BRANCH" "$REPO_URL" "$TEMP_DIR"
    cd "$TEMP_DIR"
    
    LATEST_COMMIT=$(git rev-parse HEAD)
    log_info "Latest commit: ${LATEST_COMMIT:0:8}"
    
    if [[ "$CURRENT_COMMIT" == "$LATEST_COMMIT" && "$FORCE_UPDATE" == "false" ]]; then
        log_success "✅ Already up to date!"
        rm -rf "$TEMP_DIR"
        exit 0
    fi
    
    if [[ "$FORCE_UPDATE" == "true" ]]; then
        log_warning "⚠️  Force update requested"
    else
        log_info "🆕 New version available"
    fi
}

backup_current_installation() {
    log_info "💾 Creating backup..."
    
    cp -r "$APP_DIR" "$BACKUP_DIR"
    log_success "✅ Backup created: $BACKUP_DIR"
}

stop_services() {
    log_info "⏹️  Stopping services..."
    
    cd "$APP_DIR"
    if [[ -f "docker-compose.yml" ]]; then
        docker-compose down || log_warning "Failed to stop some services"
    fi
    
    # Stop any standalone containers
    docker stop speed-test-server-container 2>/dev/null || true
    docker stop mysql-speed-test 2>/dev/null || true
    
    log_success "✅ Services stopped"
}

update_application() {
    log_info "🔄 Updating application..."
    
    cd "$APP_DIR"
    
    # Preserve important files
    PRESERVE_FILES=(
        "DEPLOYMENT_INFO.txt"
        ".env"
        "ssl/"
        "backups/"
        "logs/"
    )
    
    PRESERVE_DIR="/tmp/speed-test-preserve-$(date +%Y%m%d_%H%M%S)"
    mkdir -p "$PRESERVE_DIR"
    
    for file in "${PRESERVE_FILES[@]}"; do
        if [[ -e "$file" ]]; then
            cp -r "$file" "$PRESERVE_DIR/" 2>/dev/null || true
        fi
    done
    
    # Remove old files (except preserved ones)
    find . -mindepth 1 -maxdepth 1 ! -name "ssl" ! -name "backups" ! -name "logs" ! -name "DEPLOYMENT_INFO.txt" ! -name ".env" -exec rm -rf {} +
    
    # Copy new files
    cp -r "$TEMP_DIR"/* .
    
    # Restore preserved files
    for file in "${PRESERVE_FILES[@]}"; do
        if [[ -e "$PRESERVE_DIR/$file" ]]; then
            cp -r "$PRESERVE_DIR/$file" . 2>/dev/null || true
        fi
    done
    
    # Cleanup
    rm -rf "$PRESERVE_DIR"
    
    # Make scripts executable
    chmod +x *.sh 2>/dev/null || true
    
    log_success "✅ Application files updated"
}

rebuild_containers() {
    log_info "🔨 Rebuilding Docker containers..."
    
    cd "$APP_DIR"
    
    # Pull latest base images
    docker-compose pull 2>/dev/null || true
    
    # Rebuild containers
    docker-compose build --no-cache
    
    log_success "✅ Containers rebuilt"
}

start_services() {
    log_info "▶️  Starting services..."
    
    cd "$APP_DIR"
    docker-compose up -d
    
    # Wait for services to be ready
    sleep 10
    
    # Health check
    local attempts=0
    local max_attempts=30
    
    while [[ $attempts -lt $max_attempts ]]; do
        if curl -s http://localhost:8080/healthz >/dev/null 2>&1; then
            log_success "✅ Services started successfully"
            return 0
        fi
        
        attempts=$((attempts + 1))
        sleep 2
    done
    
    log_warning "⚠️  Services started but health check failed"
    log_info "Check logs with: cd $APP_DIR && ./logs.sh"
}

verify_update() {
    log_info "✅ Verifying update..."
    
    cd "$APP_DIR"
    
    # Check if git repository is updated
    if [[ -d ".git" ]]; then
        NEW_COMMIT=$(git rev-parse HEAD 2>/dev/null || echo "unknown")
        log_info "Updated to commit: ${NEW_COMMIT:0:8}"
    fi
    
    # Test endpoints
    if curl -s http://localhost:8080/healthz | grep -q "ok"; then
        log_success "✅ Health check passed"
    else
        log_warning "⚠️  Health check failed"
    fi
    
    if curl -s http://localhost:8080/version >/dev/null 2>&1; then
        log_success "✅ Version endpoint accessible"
    else
        log_warning "⚠️  Version endpoint not accessible"
    fi
}

cleanup() {
    log_info "🧹 Cleaning up..."
    rm -rf "$TEMP_DIR"
    
    # Clean up old Docker images
    docker image prune -f >/dev/null 2>&1 || true
}

rollback() {
    log_error "❌ Update failed. Rolling back..."
    
    if [[ -d "$BACKUP_DIR" ]]; then
        stop_services 2>/dev/null || true
        rm -rf "$APP_DIR"
        mv "$BACKUP_DIR" "$APP_DIR"
        cd "$APP_DIR"
        docker-compose up -d
        log_success "✅ Rollback completed"
    else
        log_error "No backup found for rollback"
    fi
    
    cleanup
    exit 1
}

display_completion() {
    echo ""
    echo -e "${BOLD}${GREEN}🎉 UPDATE COMPLETE! 🎉${NC}"
    echo -e "${GREEN}========================${NC}"
    echo ""
    echo -e "${BLUE}📋 Update Summary:${NC}"
    echo -e "   Previous: ${CURRENT_COMMIT:0:8}"
    echo -e "   Current:  ${NEW_COMMIT:0:8}"
    echo ""
    echo -e "${BLUE}🔧 Management Commands:${NC}"
    echo "   Status:   cd $APP_DIR && ./status.sh"
    echo "   Logs:     cd $APP_DIR && ./logs.sh"
    echo "   Restart:  cd $APP_DIR && ./restart.sh"
    echo ""
    echo -e "${BLUE}📦 Backup Location:${NC}"
    echo "   $BACKUP_DIR"
    echo ""
    echo -e "${YELLOW}💡 To rollback if needed:${NC}"
    echo "   sudo rm -rf $APP_DIR"
    echo "   sudo mv $BACKUP_DIR $APP_DIR"
    echo "   cd $APP_DIR && sudo docker-compose up -d"
    echo ""
    echo -e "${GREEN}✅ Speed Test Server updated successfully!${NC}"
}

main() {
    print_banner
    check_root
    check_installation
    get_current_version
    check_for_updates
    
    # Set trap for rollback on failure
    trap rollback ERR
    
    backup_current_installation
    stop_services
    update_application
    rebuild_containers
    start_services
    verify_update
    cleanup
    
    # Disable trap
    trap - ERR
    
    display_completion
}

# Handle interruption
trap 'log_error "Update interrupted"; rollback' INT TERM

# Run main function
main "$@"
