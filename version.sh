#!/bin/bash

# Krea Speed Test Server - Version Manager
# Usage: ./version.sh [--check-updates]

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

show_current_version() {
    echo -e "${BOLD}${BLUE}📋 Current Installation${NC}"
    echo "========================"
    
    if [[ ! -d "$APP_DIR" ]]; then
        log_error "Speed Test Server not installed at $APP_DIR"
        return 1
    fi
    
    cd "$APP_DIR"
    
    # Get Git information
    if [[ -d ".git" ]]; then
        CURRENT_COMMIT=$(git rev-parse HEAD 2>/dev/null || echo "unknown")
        CURRENT_BRANCH=$(git branch --show-current 2>/dev/null || echo "unknown")
        COMMIT_DATE=$(git show -s --format=%ci HEAD 2>/dev/null || echo "unknown")
        COMMIT_MESSAGE=$(git show -s --format=%s HEAD 2>/dev/null || echo "unknown")
        
        echo -e "${BLUE}Git Commit:${NC} ${CURRENT_COMMIT:0:8}"
        echo -e "${BLUE}Branch:${NC} $CURRENT_BRANCH"
        echo -e "${BLUE}Date:${NC} $COMMIT_DATE"
        echo -e "${BLUE}Message:${NC} $COMMIT_MESSAGE"
    else
        log_warning "Not a git repository"
    fi
    
    # Get Docker information
    if command -v docker &> /dev/null; then
        echo ""
        echo -e "${BOLD}${BLUE}🐳 Docker Status${NC}"
        echo "=================="
        
        if docker-compose ps --services 2>/dev/null | grep -q .; then
            echo -e "${BLUE}Services:${NC}"
            docker-compose ps --format "table {{.Service}}\t{{.State}}\t{{.Ports}}" 2>/dev/null || echo "Unable to get service status"
        else
            log_warning "No Docker Compose services found"
        fi
    fi
    
    # Check application health
    echo ""
    echo -e "${BOLD}${BLUE}🏥 Health Status${NC}"
    echo "=================="
    
    if curl -s http://localhost:8080/healthz >/dev/null 2>&1; then
        HEALTH_RESPONSE=$(curl -s http://localhost:8080/healthz)
        echo -e "${GREEN}✅ Application is healthy${NC}"
        echo -e "${BLUE}Response:${NC} $HEALTH_RESPONSE"
    else
        echo -e "${RED}❌ Application health check failed${NC}"
    fi
    
    if curl -s http://localhost:8080/version >/dev/null 2>&1; then
        VERSION_RESPONSE=$(curl -s http://localhost:8080/version)
        echo -e "${BLUE}Version endpoint:${NC} $VERSION_RESPONSE"
    fi
}

check_for_updates() {
    echo ""
    echo -e "${BOLD}${BLUE}🔍 Checking for Updates${NC}"
    echo "========================="
    
    if [[ ! -d "$APP_DIR/.git" ]]; then
        log_warning "Not a git repository. Cannot check for updates."
        return 1
    fi
    
    cd "$APP_DIR"
    
    # Fetch latest changes
    log_info "Fetching latest changes..."
    git fetch origin >/dev/null 2>&1 || {
        log_error "Failed to fetch from remote repository"
        return 1
    }
    
    CURRENT_COMMIT=$(git rev-parse HEAD)
    LATEST_COMMIT=$(git rev-parse origin/$(git branch --show-current))
    
    echo -e "${BLUE}Current:${NC} ${CURRENT_COMMIT:0:8}"
    echo -e "${BLUE}Latest:${NC}  ${LATEST_COMMIT:0:8}"
    
    if [[ "$CURRENT_COMMIT" == "$LATEST_COMMIT" ]]; then
        log_success "✅ You are up to date!"
    else
        log_warning "🆕 New version available!"
        echo ""
        echo -e "${YELLOW}Changes since your version:${NC}"
        git log --oneline $CURRENT_COMMIT..$LATEST_COMMIT 2>/dev/null || echo "Unable to show changes"
        echo ""
        echo -e "${BLUE}To update, run:${NC} sudo ./update.sh"
    fi
}

show_help() {
    echo "Krea Speed Test Server - Version Manager"
    echo ""
    echo "Usage: $0 [OPTIONS]"
    echo ""
    echo "Options:"
    echo "  --check-updates    Check for available updates"
    echo "  --help            Show this help message"
    echo ""
    echo "Examples:"
    echo "  $0                 Show current version info"
    echo "  $0 --check-updates Show version info and check for updates"
}

main() {
    case "${1:-}" in
        --check-updates)
            show_current_version
            check_for_updates
            ;;
        --help|-h)
            show_help
            ;;
        "")
            show_current_version
            ;;
        *)
            echo "Unknown option: $1"
            show_help
            exit 1
            ;;
    esac
}

main "$@"
