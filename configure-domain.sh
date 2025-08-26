#!/bin/bash

# Domain Configuration Script for Krea Speed Test Server
# This script helps configure the correct domain/URL settings for deployment

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

# Check if domain is provided
if [[ $# -eq 0 ]]; then
    log_error "Usage: $0 <domain> [scheme]"
    echo ""
    echo "Examples:"
    echo "  $0 speedtest.example.com"
    echo "  $0 speedtest.example.com https"
    echo "  $0 192.168.1.100:8080 http"
    echo ""
    exit 1
fi

DOMAIN="$1"
SCHEME="${2:-https}"  # Default to https

log_info "Configuring domain: $DOMAIN"
log_info "Using scheme: $SCHEME"

# Validate domain format
if [[ ! $DOMAIN =~ ^[a-zA-Z0-9.-]+(\:[0-9]+)?$ ]]; then
    log_error "Invalid domain format: $DOMAIN"
    exit 1
fi

# Create or update .env file
ENV_FILE=".env"
log_info "Creating/updating $ENV_FILE..."

cat > "$ENV_FILE" << EOF
# Server Configuration
PORT=8080

# External URLs Configuration
SERVER_URL=${SCHEME}://${DOMAIN}
SWAGGER_HOST=${DOMAIN}

# MySQL Database Configuration
MYSQL_ROOT_PASSWORD=speedtest_root_password_$(date +%s)
MYSQL_DATABASE=speedtest
MYSQL_USER=speedtest
MYSQL_PASSWORD=speedtest_$(date +%s | tail -c 6)

# Database Connection URL (for application)
DATABASE_URL=speedtest:speedtest@tcp(mysql:3306)/speedtest?charset=utf8mb4&parseTime=True&loc=Local

# IPInfo.io API Token (optional, fallback token is provided)
IPINFO_TOKEN=20e16b08cd509a

# Application Configuration
ENVIRONMENT=production
LOG_LEVEL=info
DEBUG=false

# Rate Limiting Configuration
RATE_LIMIT_ENABLED=true
RATE_LIMIT_REQUESTS_PER_MINUTE=60

# JWT Secret for API authentication
JWT_SECRET=$(openssl rand -base64 32 | tr -d "=+/" | cut -c1-32)

# Admin API Key
ADMIN_API_KEY=$(openssl rand -base64 32 | tr -d "=+/" | cut -c1-32)

# Demo API Key
DEMO_API_KEY_ENABLED=true

# Application Name
APP_NAME=speed-test
EOF

log_success "Created $ENV_FILE with domain configuration"

# Update any localhost references in example files for reference
log_info "Updating documentation examples..."

# Update README.md if it exists
if [[ -f "README.md" ]]; then
    sed -i.bak "s|localhost:8080|${DOMAIN}|g" README.md
    sed -i.bak "s|http://|${SCHEME}://|g" README.md
    log_success "Updated README.md examples"
fi

# Update test scripts
if [[ -f "setup-dev.sh" ]]; then
    cp setup-dev.sh setup-dev.sh.bak
    sed -i "s|http://localhost:8080|${SCHEME}://${DOMAIN}|g" setup-dev.sh
    log_success "Updated setup-dev.sh examples"
fi

# Update client configuration for testing
log_info "Client applications can now use:"
echo "  export SERVER_URL=${SCHEME}://${DOMAIN}"
echo "  ./client/speed-test-client"

log_info "Configuration completed for domain: $DOMAIN"
log_info "Next steps:"
echo "  1. Review the generated .env file"
echo "  2. Run: ./deploy.sh $DOMAIN"
echo "  3. Access your speed test at: ${SCHEME}://${DOMAIN}"
echo "  4. View API docs at: ${SCHEME}://${DOMAIN}/swagger/"

log_warning "Make sure your domain DNS is properly configured to point to this server"
