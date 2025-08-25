#!/bin/bash

# Krea Speed Test Server - Docker Production Deployment
# This script deploys using Docker with SSL and auto-renewal

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
DOMAIN="$1"
EMAIL="${2:-admin@${DOMAIN}}"
ADMIN_API_KEY=$(openssl rand -hex 32)
MYSQL_ROOT_PASSWORD=$(openssl rand -base64 32)
MYSQL_DB_PASSWORD=$(openssl rand -base64 32)

# Functions
log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

check_prerequisites() {
    if [[ -z "$DOMAIN" ]]; then
        log_error "Usage: $0 <domain> [email]"
        log_error "Example: $0 speedtest.example.com admin@example.com"
        exit 1
    fi
    
    if ! command -v docker &> /dev/null; then
        log_error "Docker is not installed. Please install Docker first."
        exit 1
    fi
    
    if ! command -v docker-compose &> /dev/null; then
        log_error "Docker Compose is not installed. Please install Docker Compose first."
        exit 1
    fi
}

create_production_compose() {
    log_info "Creating production Docker Compose configuration..."
    
    cat > docker-compose.prod.yml <<EOF
version: '3.8'

services:
  mysql:
    image: mysql:8.0
    container_name: speedtest-mysql
    restart: unless-stopped
    environment:
      MYSQL_ROOT_PASSWORD: ${MYSQL_ROOT_PASSWORD}
      MYSQL_DATABASE: speedtest
      MYSQL_USER: speedtest
      MYSQL_PASSWORD: ${MYSQL_DB_PASSWORD}
    volumes:
      - mysql_data:/var/lib/mysql
      - ./migrations:/docker-entrypoint-initdb.d:ro
    ports:
      - "127.0.0.1:3306:3306"
    networks:
      - speedtest-network
    healthcheck:
      test: ["CMD", "mysqladmin", "ping", "-h", "localhost"]
      timeout: 20s
      retries: 10

  app:
    build: .
    container_name: speedtest-app
    restart: unless-stopped
    depends_on:
      mysql:
        condition: service_healthy
    environment:
      - PORT=8080
      - DATABASE_URL=mysql://speedtest:${MYSQL_DB_PASSWORD}@mysql:3306/speedtest
      - IPINFO_TOKEN=20e16b08cd509a
      - ENVIRONMENT=production
      - LOG_LEVEL=info
      - ADMIN_API_KEY=${ADMIN_API_KEY}
    ports:
      - "127.0.0.1:8080:8080"
    networks:
      - speedtest-network
    healthcheck:
      test: ["CMD", "curl", "-f", "http://localhost:8080/healthz"]
      interval: 30s
      timeout: 10s
      retries: 3

  nginx:
    image: nginx:alpine
    container_name: speedtest-nginx
    restart: unless-stopped
    ports:
      - "80:80"
      - "443:443"
    volumes:
      - ./nginx.conf:/etc/nginx/nginx.conf:ro
      - certbot_conf:/etc/letsencrypt
      - certbot_www:/var/www/certbot
    depends_on:
      - app
    networks:
      - speedtest-network

  certbot:
    image: certbot/certbot
    container_name: speedtest-certbot
    volumes:
      - certbot_conf:/etc/letsencrypt
      - certbot_www:/var/www/certbot
    command: certonly --webroot -w /var/www/certbot --force-renewal --email ${EMAIL} -d ${DOMAIN} --agree-tos --no-eff-email

volumes:
  mysql_data:
  certbot_conf:
  certbot_www:

networks:
  speedtest-network:
    driver: bridge
EOF
}

create_nginx_config() {
    log_info "Creating Nginx configuration..."
    
    cat > nginx.conf <<EOF
events {
    worker_connections 1024;
}

http {
    include       /etc/nginx/mime.types;
    default_type  application/octet-stream;

    log_format main '\$remote_addr - \$remote_user [\$time_local] "\$request" '
                    '\$status \$body_bytes_sent "\$http_referer" '
                    '"\$http_user_agent" "\$http_x_forwarded_for"';

    access_log /var/log/nginx/access.log main;
    sendfile on;
    keepalive_timeout 65;
    
    # Rate limiting
    limit_req_zone \$binary_remote_addr zone=api:10m rate=10r/s;

    server {
        listen 80;
        server_name ${DOMAIN};

        location /.well-known/acme-challenge/ {
            root /var/www/certbot;
        }

        location / {
            return 301 https://\$server_name\$request_uri;
        }
    }

    server {
        listen 443 ssl http2;
        server_name ${DOMAIN};

        ssl_certificate /etc/letsencrypt/live/${DOMAIN}/fullchain.pem;
        ssl_certificate_key /etc/letsencrypt/live/${DOMAIN}/privkey.pem;
        
        # Security headers
        add_header X-Frame-Options DENY;
        add_header X-Content-Type-Options nosniff;
        add_header X-XSS-Protection "1; mode=block";
        add_header Strict-Transport-Security "max-age=31536000; includeSubDomains" always;

        # Apply rate limiting to API endpoints
        location /api/ {
            limit_req zone=api burst=20 nodelay;
            proxy_pass http://app:8080;
            proxy_http_version 1.1;
            proxy_set_header Upgrade \$http_upgrade;
            proxy_set_header Connection 'upgrade';
            proxy_set_header Host \$host;
            proxy_set_header X-Real-IP \$remote_addr;
            proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
            proxy_set_header X-Forwarded-Proto \$scheme;
            proxy_cache_bypass \$http_upgrade;
        }

        location / {
            proxy_pass http://app:8080;
            proxy_http_version 1.1;
            proxy_set_header Upgrade \$http_upgrade;
            proxy_set_header Connection 'upgrade';
            proxy_set_header Host \$host;
            proxy_set_header X-Real-IP \$remote_addr;
            proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
            proxy_set_header X-Forwarded-Proto \$scheme;
            proxy_cache_bypass \$http_upgrade;
        }

        # WebSocket support
        location /ws {
            proxy_pass http://app:8080;
            proxy_http_version 1.1;
            proxy_set_header Upgrade \$http_upgrade;
            proxy_set_header Connection "upgrade";
            proxy_set_header Host \$host;
            proxy_set_header X-Real-IP \$remote_addr;
            proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
            proxy_set_header X-Forwarded-Proto \$scheme;
        }
    }
}
EOF
}

create_ssl_renewal_script() {
    log_info "Creating SSL renewal script..."
    
    cat > renew-ssl.sh <<'EOF'
#!/bin/bash
# SSL Certificate Renewal Script for Docker

set -e

echo "$(date): Starting SSL certificate renewal..."

# Renew certificates
docker-compose -f docker-compose.prod.yml run --rm certbot renew

# Reload Nginx
docker-compose -f docker-compose.prod.yml exec nginx nginx -s reload

echo "$(date): SSL certificate renewal completed successfully"
EOF
    
    chmod +x renew-ssl.sh
}

create_management_scripts() {
    log_info "Creating management scripts..."
    
    # Start script
    cat > start.sh <<'EOF'
#!/bin/bash
docker-compose -f docker-compose.prod.yml up -d
EOF
    
    # Stop script
    cat > stop.sh <<'EOF'
#!/bin/bash
docker-compose -f docker-compose.prod.yml down
EOF
    
    # Logs script
    cat > logs.sh <<'EOF'
#!/bin/bash
docker-compose -f docker-compose.prod.yml logs -f "${1:-app}"
EOF
    
    # Status script
    cat > status.sh <<'EOF'
#!/bin/bash
docker-compose -f docker-compose.prod.yml ps
EOF
    
    # Backup script
    cat > backup.sh <<EOF
#!/bin/bash
# Backup MySQL database
docker-compose -f docker-compose.prod.yml exec mysql mysqldump -u speedtest -p${MYSQL_DB_PASSWORD} speedtest > backup-\$(date +%Y%m%d-%H%M%S).sql
EOF
    
    chmod +x start.sh stop.sh logs.sh status.sh backup.sh
}

setup_cron_renewal() {
    log_info "Setting up SSL auto-renewal cron job..."
    
    # Add cron job for SSL renewal every 80 days
    (crontab -l 2>/dev/null; echo "0 3 */40 * * cd $(pwd) && ./renew-ssl.sh >> ssl-renewal.log 2>&1") | crontab -
    
    log_success "SSL auto-renewal cron job configured"
}

initialize_ssl() {
    log_info "Initializing SSL certificates..."
    
    # Create dummy certificates for initial setup
    docker-compose -f docker-compose.prod.yml up -d nginx
    
    # Wait for nginx to start
    sleep 10
    
    # Get initial certificates
    docker-compose -f docker-compose.prod.yml run --rm certbot certonly --webroot -w /var/www/certbot --email "$EMAIL" -d "$DOMAIN" --agree-tos --no-eff-email
    
    # Reload nginx with real certificates
    docker-compose -f docker-compose.prod.yml exec nginx nginx -s reload
    
    log_success "SSL certificates initialized"
}

deploy() {
    log_info "🚀 Starting Docker-based deployment for $DOMAIN"
    echo "============================================="
    
    check_prerequisites
    create_production_compose
    create_nginx_config
    create_ssl_renewal_script
    create_management_scripts
    
    # Build and start services
    log_info "Building and starting services..."
    docker-compose -f docker-compose.prod.yml build
    docker-compose -f docker-compose.prod.yml up -d mysql app
    
    # Wait for services to be healthy
    log_info "Waiting for services to be ready..."
    sleep 30
    
    # Initialize SSL
    initialize_ssl
    
    # Setup SSL renewal
    setup_cron_renewal
    
    # Insert admin API key
    log_info "Setting up admin API key..."
    sleep 10
    docker-compose -f docker-compose.prod.yml exec mysql mysql -u speedtest -p"$MYSQL_DB_PASSWORD" speedtest -e "INSERT INTO api_keys (api_key, name, is_active, rate_limit_per_hour, created_at, updated_at) VALUES ('$ADMIN_API_KEY', 'admin', 1, 10000, NOW(), NOW()) ON DUPLICATE KEY UPDATE name='admin', is_active=1, rate_limit_per_hour=10000, updated_at=NOW();"
    
    # Display summary
    echo ""
    log_success "🎉 DOCKER DEPLOYMENT COMPLETE! 🎉"
    echo "=================================="
    echo ""
    echo -e "${GREEN}📍 Application URL:${NC} https://$DOMAIN"
    echo -e "${GREEN}📍 Swagger Documentation:${NC} https://$DOMAIN/swagger/index.html"
    echo -e "${GREEN}📍 Health Check:${NC} https://$DOMAIN/healthz"
    echo ""
    echo -e "${BLUE}🔐 CREDENTIALS:${NC}"
    echo "  MySQL Root Password: $MYSQL_ROOT_PASSWORD"
    echo "  MySQL App Password: $MYSQL_DB_PASSWORD"
    echo "  Admin API Key: $ADMIN_API_KEY"
    echo ""
    echo -e "${BLUE}🔧 MANAGEMENT COMMANDS:${NC}"
    echo "  Start services: ./start.sh"
    echo "  Stop services: ./stop.sh"
    echo "  View logs: ./logs.sh [service]"
    echo "  Service status: ./status.sh"
    echo "  Backup database: ./backup.sh"
    echo "  Renew SSL: ./renew-ssl.sh"
    echo ""
    
    # Save deployment info
    cat > DEPLOYMENT_INFO.txt <<EOF
Krea Speed Test Server - Docker Deployment
==========================================

Domain: $DOMAIN
Email: $EMAIL
Deployed: $(date)

CREDENTIALS:
MySQL Root Password: $MYSQL_ROOT_PASSWORD
MySQL App Password: $MYSQL_DB_PASSWORD
Admin API Key: $ADMIN_API_KEY

URLS:
Application: https://$DOMAIN
Swagger Docs: https://$DOMAIN/swagger/index.html
Health Check: https://$DOMAIN/healthz

MANAGEMENT:
Start: ./start.sh
Stop: ./stop.sh
Logs: ./logs.sh [service]
Status: ./status.sh
Backup: ./backup.sh
SSL Renewal: ./renew-ssl.sh
EOF
    
    log_success "Deployment completed! Check DEPLOYMENT_INFO.txt for details."
}

# Run deployment
deploy "$@"
