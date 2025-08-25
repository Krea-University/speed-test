#!/bin/bash

# Krea Speed Test Server - Docker Production Deployment with Auto-Restart & Daily Backups
# This script deploys the speed test server using Docker with SSL, auto-restart, and daily MySQL backups
# Usage: ./deploy.sh [--no-tty] <domain> [email]
# 
# Options:
#   --no-tty              Force non-interactive mode (disable TTY)
# 
# Environment Variables:
#   DOCKER_NONINTERACTIVE=1 - Force non-interactive mode if TTY detection fails

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Parse command line arguments
FORCE_NO_TTY=false
ARGS=()

while [[ $# -gt 0 ]]; do
    case $1 in
        --no-tty)
            FORCE_NO_TTY=true
            export DOCKER_NONINTERACTIVE=1
            shift
            ;;
        *)
            ARGS+=("$1")
            shift
            ;;
    esac
done

# Set positional parameters from remaining args
set -- "${ARGS[@]}"

# Configuration
DOMAIN="$1"
EMAIL="${2:-admin@${DOMAIN}}"
APP_NAME="speed-test-server"
BACKUP_DIR="/var/backup/speed-test-server"
ADMIN_API_KEY=$(openssl rand -hex 32)
MYSQL_ROOT_PASSWORD=$(openssl rand -base64 32)
MYSQL_DB_PASSWORD=$(openssl rand -base64 32)

# Functions
# Docker Compose wrapper for non-interactive environments
docker_exec() {
    # Force non-interactive if --no-tty was specified
    if [[ "${FORCE_NO_TTY}" == "true" ]] || [[ "${DOCKER_NONINTERACTIVE}" == "1" ]]; then
        docker-compose exec -T "$@"
    # Try TTY detection
    elif [ -t 0 ]; then
        docker-compose exec "$@"
    else
        # Use -T flag for non-interactive mode
        docker-compose exec -T "$@"
    fi
}

# Alternative wrapper using environment variable override
docker_exec_safe() {
    # Force non-interactive mode if DOCKER_NONINTERACTIVE is set or --no-tty flag
    if [[ "${DOCKER_NONINTERACTIVE}" == "1" ]] || [[ "${FORCE_NO_TTY}" == "true" ]]; then
        docker-compose exec -T "$@"
    else
        docker_exec "$@"
    fi
}

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

# Safe file creation - removes directory if exists, creates file
safe_create_file() {
    local filename="$1"
    local content="$2"
    
    if [[ -d "$filename" ]]; then
        log_warning "Found $filename directory, removing it..."
        rm -rf "$filename"
    fi
    
    echo "$content" > "$filename" || {
        log_error "Failed to create $filename"
        exit 1
    }
}

cleanup_conflicting_files() {
    log_info "Cleaning up any conflicting files/directories..."
    
    # List of files that should not be directories
    local config_files=(".env" "docker-compose.yml" "nginx.conf" "backup-script.sh" 
                       "start.sh" "stop.sh" "restart.sh" "logs.sh" "status.sh" 
                       "backup-now.sh" "restore.sh" "renew-ssl.sh" "update.sh" 
                       "version.sh" "DEPLOYMENT_INFO.txt")
    
    for file in "${config_files[@]}"; do
        if [[ -d "$file" ]]; then
            log_warning "Found $file directory, removing it..."
            rm -rf "$file"
        fi
    done
}

check_root() {
    if [[ $EUID -ne 0 ]]; then
        log_error "This script must be run as root (use sudo)"
        exit 1
    fi
}

check_domain() {
    if [[ -z "$DOMAIN" ]]; then
        log_error "Usage: $0 [--no-tty] <domain> [email]"
        log_error "Example: $0 speedtest.example.com admin@example.com"
        log_error "Example: $0 --no-tty speedtest.example.com admin@example.com"
        exit 1
    fi
    
    log_info "Deploying for domain: $DOMAIN"
    log_info "Contact email: $EMAIL"
    if [[ "${FORCE_NO_TTY}" == "true" ]]; then
        log_info "Mode: Non-interactive (--no-tty specified)"
    fi
}

check_prerequisites() {
    log_info "Checking prerequisites..."
    
    # Check if running on supported OS
    if ! command -v apt-get &> /dev/null && ! command -v yum &> /dev/null; then
        log_error "This script supports Ubuntu/Debian (apt) and CentOS/RHEL (yum) only"
        exit 1
    fi
    
    # Detect OS
    if command -v apt-get &> /dev/null; then
        OS="ubuntu"
        PKG_MANAGER="apt-get"
        PKG_UPDATE="apt-get update"
        PKG_INSTALL="apt-get install -y"
    else
        OS="centos"
        PKG_MANAGER="yum"
        PKG_UPDATE="yum update -y"
        PKG_INSTALL="yum install -y"
    fi
    
    log_success "Detected OS: $OS"
}

install_docker() {
    log_info "Installing Docker and Docker Compose..."
    
    if command -v docker &> /dev/null; then
        log_warning "Docker already installed"
    else
        if [[ "$OS" == "ubuntu" ]]; then
            # Install Docker on Ubuntu
            $PKG_UPDATE
            $PKG_INSTALL ca-certificates curl gnupg lsb-release
            
            # Add Docker's official GPG key
            curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg
            
            # Set up the stable repository
            echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" | tee /etc/apt/sources.list.d/docker.list > /dev/null
            
            # Install Docker Engine
            $PKG_UPDATE
            $PKG_INSTALL docker-ce docker-ce-cli containerd.io docker-compose-plugin
        else
            # Install Docker on CentOS
            $PKG_UPDATE
            $PKG_INSTALL yum-utils
            yum-config-manager --add-repo https://download.docker.com/linux/centos/docker-ce.repo
            $PKG_INSTALL docker-ce docker-ce-cli containerd.io docker-compose-plugin
        fi
        
        # Start and enable Docker
        systemctl start docker
        systemctl enable docker
        
        log_success "Docker installed and started"
    fi
    
    # Install Docker Compose if not present
    if ! command -v docker-compose &> /dev/null; then
        log_info "Installing Docker Compose..."
        curl -L "https://github.com/docker/compose/releases/latest/download/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
        chmod +x /usr/local/bin/docker-compose
        log_success "Docker Compose installed"
    fi
}

create_directories() {
    log_info "Creating application and backup directories..."
    
    # Create backup directory
    mkdir -p "$BACKUP_DIR"
    chmod 755 "$BACKUP_DIR"
    
    # Create application directory
    mkdir -p "/opt/$APP_NAME"
    cd "/opt/$APP_NAME"
    
    log_success "Directories created"
}

create_environment_file() {
    log_info "Creating environment file..."
    
    # Remove .env if it exists as a directory
    if [[ -d ".env" ]]; then
        log_warning "Found .env directory, removing it..."
        rm -rf .env
    fi
    
    cat > .env <<EOF
# Krea Speed Test Server Environment Configuration
# Generated on $(date)

# Database Configuration
MYSQL_ROOT_PASSWORD=${MYSQL_ROOT_PASSWORD}
MYSQL_DATABASE=speedtest
MYSQL_USER=speedtest
MYSQL_PASSWORD=${MYSQL_DB_PASSWORD}

# Application Configuration
PORT=8080
ENVIRONMENT=production
LOG_LEVEL=info
ADMIN_API_KEY=${ADMIN_API_KEY}

# IP Geolocation Service
IPINFO_TOKEN=20e16b08cd509a

# Rate Limiting
RATE_LIMIT_ENABLED=true
EOF
    
    log_success "Environment file created"
}

create_docker_compose() {
    log_info "Creating Docker Compose configuration..."
    
    # Remove docker-compose.yml if it exists as a directory
    if [[ -d "docker-compose.yml" ]]; then
        log_warning "Found docker-compose.yml directory, removing it..."
        rm -rf docker-compose.yml
    fi
    
    cat > docker-compose.yml <<EOF
services:
  mysql:
    image: mysql:8.0
    container_name: ${APP_NAME}-mysql
    restart: unless-stopped
    environment:
      MYSQL_ROOT_PASSWORD: \${MYSQL_ROOT_PASSWORD}
      MYSQL_DATABASE: \${MYSQL_DATABASE}
      MYSQL_USER: \${MYSQL_USER}
      MYSQL_PASSWORD: \${MYSQL_PASSWORD}
    volumes:
      - mysql_data:/var/lib/mysql
      - ./migrations:/docker-entrypoint-initdb.d:ro
      - ${BACKUP_DIR}:/var/backup:rw
    ports:
      - "127.0.0.1:3306:3306"
    networks:
      - speedtest-network
    healthcheck:
      test: ["CMD", "mysqladmin", "ping", "-h", "localhost", "-u", "root", "-p\${MYSQL_ROOT_PASSWORD}"]
      timeout: 20s
      retries: 10
      interval: 30s
    command: >
      --innodb-buffer-pool-size=256M
      --max-connections=200
      --innodb-log-file-size=64M

  app:
    build: .
    container_name: ${APP_NAME}-app
    restart: unless-stopped
    depends_on:
      mysql:
        condition: service_healthy
    environment:
      - PORT=\${PORT}
      - DATABASE_URL=mysql://\${MYSQL_USER}:\${MYSQL_PASSWORD}@mysql:3306/\${MYSQL_DATABASE}
      - IPINFO_TOKEN=\${IPINFO_TOKEN}
      - ENVIRONMENT=\${ENVIRONMENT}
      - LOG_LEVEL=\${LOG_LEVEL}
      - ADMIN_API_KEY=\${ADMIN_API_KEY}
      - RATE_LIMIT_ENABLED=\${RATE_LIMIT_ENABLED}
    ports:
      - "127.0.0.1:8080:8080"
    networks:
      - speedtest-network
    healthcheck:
      test: ["CMD", "wget", "--no-verbose", "--tries=1", "--spider", "http://localhost:8080/healthz"]
      interval: 30s
      timeout: 10s
      retries: 3
      start_period: 40s
    volumes:
      - app_logs:/app/logs

  nginx:
    image: nginx:alpine
    container_name: ${APP_NAME}-nginx
    restart: unless-stopped
    ports:
      - "80:80"
      - "443:443"
    volumes:
      - ./nginx.conf:/etc/nginx/nginx.conf:ro
      - ./ssl:/etc/nginx/ssl:ro
      - certbot_conf:/etc/letsencrypt:ro
      - certbot_www:/var/www/certbot:ro
      - nginx_logs:/var/log/nginx
    depends_on:
      - app
    networks:
      - speedtest-network
    healthcheck:
      test: ["CMD", "wget", "--no-verbose", "--tries=1", "--spider", "http://localhost:80/"]
      interval: 30s
      timeout: 10s
      retries: 3

  certbot:
    image: certbot/certbot
    container_name: ${APP_NAME}-certbot
    volumes:
      - certbot_conf:/etc/letsencrypt
      - certbot_www:/var/www/certbot
    command: certonly --webroot -w /var/www/certbot --force-renewal --email ${EMAIL} -d ${DOMAIN} --agree-tos --no-eff-email
    depends_on:
      - nginx

  # Daily backup service
  backup:
    image: mysql:8.0
    container_name: ${APP_NAME}-backup
    restart: unless-stopped
    depends_on:
      - mysql
    environment:
      - MYSQL_PWD=${MYSQL_DB_PASSWORD}
    volumes:
      - ${BACKUP_DIR}:/backup
      - ./backup-script.sh:/backup-script.sh:ro
    networks:
      - speedtest-network
    command: >
      sh -c "
        echo '0 2 * * * /backup-script.sh >> /backup/backup.log 2>&1' > /etc/crontabs/root &&
        crond -f -l 2
      "
    entrypoint: ["/bin/sh"]

volumes:
  mysql_data:
    driver: local
  app_logs:
    driver: local
  nginx_logs:
    driver: local
  certbot_conf:
    driver: local
  certbot_www:
    driver: local

networks:
  speedtest-network:
    driver: bridge
    ipam:
      config:
        - subnet: 172.20.0.0/16
EOF

    log_success "Docker Compose configuration created"
}

create_nginx_config() {
    log_info "Creating Nginx configuration..."
    
    # Remove nginx.conf if it exists as a directory
    if [[ -d "nginx.conf" ]]; then
        log_warning "Found nginx.conf directory, removing it..."
        rm -rf nginx.conf
    fi
    
    # Create nginx.conf file with error checking
    cat > nginx.conf <<EOF
events {
    worker_connections 1024;
    use epoll;
    multi_accept on;
}

http {
    include       /etc/nginx/mime.types;
    default_type  application/octet-stream;

    # Logging
    log_format main '\$remote_addr - \$remote_user [\$time_local] "\$request" '
                    '\$status \$body_bytes_sent "\$http_referer" '
                    '"\$http_user_agent" "\$http_x_forwarded_for" '
                    'rt=\$request_time uct="\$upstream_connect_time" '
                    'uht="\$upstream_header_time" urt="\$upstream_response_time"';

    access_log /var/log/nginx/access.log main;
    error_log /var/log/nginx/error.log warn;

    # Performance
    sendfile on;
    tcp_nopush on;
    tcp_nodelay on;
    keepalive_timeout 65;
    types_hash_max_size 2048;
    client_max_body_size 100M;
    
    # Gzip compression
    gzip on;
    gzip_vary on;
    gzip_min_length 1024;
    gzip_types text/plain text/css text/xml text/javascript application/javascript application/xml+rss application/json;
    
    # Rate limiting zones
    limit_req_zone \$binary_remote_addr zone=api:10m rate=10r/s;
    limit_req_zone \$binary_remote_addr zone=general:10m rate=30r/s;

    # HTTP server (redirect to HTTPS)
    server {
        listen 80;
        server_name ${DOMAIN};

        # Let's Encrypt challenge
        location /.well-known/acme-challenge/ {
            root /var/www/certbot;
        }

        # Redirect all other traffic to HTTPS
        location / {
            return 301 https://\$server_name\$request_uri;
        }
    }

    # HTTPS server
    server {
        listen 443 ssl http2;
        server_name ${DOMAIN};

        # SSL Configuration
        ssl_certificate /etc/letsencrypt/live/${DOMAIN}/fullchain.pem;
        ssl_certificate_key /etc/letsencrypt/live/${DOMAIN}/privkey.pem;
        
        # SSL Security
        ssl_protocols TLSv1.2 TLSv1.3;
        ssl_ciphers ECDHE-RSA-AES256-GCM-SHA512:DHE-RSA-AES256-GCM-SHA512:ECDHE-RSA-AES256-GCM-SHA384:DHE-RSA-AES256-GCM-SHA384;
        ssl_prefer_server_ciphers off;
        ssl_session_cache shared:SSL:10m;
        ssl_session_timeout 10m;
        
        # Security headers
        add_header X-Frame-Options DENY always;
        add_header X-Content-Type-Options nosniff always;
        add_header X-XSS-Protection "1; mode=block" always;
        add_header Strict-Transport-Security "max-age=31536000; includeSubDomains; preload" always;
        add_header Referrer-Policy "strict-origin-when-cross-origin" always;
        add_header Content-Security-Policy "default-src 'self'; script-src 'self' 'unsafe-inline' 'unsafe-eval'; style-src 'self' 'unsafe-inline'; img-src 'self' data: https:;" always;

        # Rate limiting for API endpoints
        location /api/ {
            limit_req zone=api burst=20 nodelay;
            limit_req_status 429;
            
            proxy_pass http://app:8080;
            proxy_http_version 1.1;
            proxy_set_header Upgrade \$http_upgrade;
            proxy_set_header Connection 'upgrade';
            proxy_set_header Host \$host;
            proxy_set_header X-Real-IP \$remote_addr;
            proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
            proxy_set_header X-Forwarded-Proto \$scheme;
            proxy_cache_bypass \$http_upgrade;
            
            # Timeouts
            proxy_connect_timeout 30s;
            proxy_send_timeout 30s;
            proxy_read_timeout 30s;
        }

        # WebSocket support with rate limiting
        location /ws {
            limit_req zone=general burst=10 nodelay;
            
            proxy_pass http://app:8080;
            proxy_http_version 1.1;
            proxy_set_header Upgrade \$http_upgrade;
            proxy_set_header Connection "upgrade";
            proxy_set_header Host \$host;
            proxy_set_header X-Real-IP \$remote_addr;
            proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
            proxy_set_header X-Forwarded-Proto \$scheme;
            
            # WebSocket timeouts
            proxy_read_timeout 3600s;
            proxy_send_timeout 3600s;
        }

        # General application traffic
        location / {
            limit_req zone=general burst=50 nodelay;
            
            proxy_pass http://app:8080;
            proxy_http_version 1.1;
            proxy_set_header Upgrade \$http_upgrade;
            proxy_set_header Connection 'upgrade';
            proxy_set_header Host \$host;
            proxy_set_header X-Real-IP \$remote_addr;
            proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
            proxy_set_header X-Forwarded-Proto \$scheme;
            proxy_cache_bypass \$http_upgrade;
            
            # Timeouts
            proxy_connect_timeout 30s;
            proxy_send_timeout 30s;
            proxy_read_timeout 30s;
        }

        # Static files caching
        location ~* \.(js|css|png|jpg|jpeg|gif|ico|svg|woff|woff2|ttf|eot)$ {
            expires 1y;
            add_header Cache-Control "public, immutable";
            access_log off;
        }
        
        # Health check endpoint (no rate limiting)
        location /healthz {
            proxy_pass http://app:8080;
            access_log off;
        }
    }
}
EOF

    # Check if the file creation was successful
    if [[ $? -ne 0 ]]; then
        log_error "Failed to create nginx.conf - check permissions and disk space"
        exit 1
    fi

    # Verify nginx.conf was created successfully
    if [[ -f "nginx.conf" ]]; then
        log_success "Nginx configuration created successfully"
    else
        log_error "Failed to create nginx.conf file"
        exit 1
    fi
}

create_backup_script() {
    log_info "Creating daily backup script..."
    
    cat > backup-script.sh <<EOF
#!/bin/bash

# MySQL Daily Backup Script for Docker
# Runs daily at 2 AM via cron in backup container

set -e

# Configuration
BACKUP_DIR="/backup"
DATE=\$(date +%Y%m%d_%H%M%S)
RETENTION_DAYS=30

# Create backup directory if it doesn't exist
mkdir -p "\$BACKUP_DIR"

# Database connection details
DB_HOST="mysql"
DB_USER="speedtest"
DB_NAME="speedtest"
# Password is set via MYSQL_PWD environment variable

echo "\$(date): Starting MySQL backup..."

# Create backup
mysqldump -h "\$DB_HOST" -u "\$DB_USER" "\$DB_NAME" > "\$BACKUP_DIR/speedtest_backup_\$DATE.sql"

# Compress backup
gzip "\$BACKUP_DIR/speedtest_backup_\$DATE.sql"

# Verify backup was created
if [[ -f "\$BACKUP_DIR/speedtest_backup_\$DATE.sql.gz" ]]; then
    BACKUP_SIZE=\$(du -h "\$BACKUP_DIR/speedtest_backup_\$DATE.sql.gz" | cut -f1)
    echo "\$(date): Backup completed successfully - speedtest_backup_\$DATE.sql.gz (\$BACKUP_SIZE)"
else
    echo "\$(date): ERROR - Backup failed!"
    exit 1
fi

# Clean up old backups (keep last 30 days)
echo "\$(date): Cleaning up old backups (keeping last \$RETENTION_DAYS days)..."
find "\$BACKUP_DIR" -name "speedtest_backup_*.sql.gz" -type f -mtime +\$RETENTION_DAYS -delete

# Log current backup status
echo "\$(date): Current backups:"
ls -lah "\$BACKUP_DIR"/speedtest_backup_*.sql.gz 2>/dev/null || echo "No backup files found"

echo "\$(date): Backup process completed"
EOF

    chmod +x backup-script.sh
    log_success "Backup script created"
}

create_management_scripts() {
    log_info "Creating management scripts..."
    
    # Start script
    cat > start.sh <<'EOF'
#!/bin/bash
echo "Starting Krea Speed Test Server..."
docker-compose up -d
echo "Services started. Use './logs.sh' to view logs."
EOF
    
    # Stop script
    cat > stop.sh <<'EOF'
#!/bin/bash
echo "Stopping Krea Speed Test Server..."
docker-compose down
echo "Services stopped."
EOF
    
    # Restart script
    cat > restart.sh <<'EOF'
#!/bin/bash
echo "Restarting Krea Speed Test Server..."
docker-compose restart
echo "Services restarted."
EOF
    
    # Logs script
    cat > logs.sh <<'EOF'
#!/bin/bash
SERVICE=${1:-app}
echo "Showing logs for service: $SERVICE"
echo "Available services: app, mysql, nginx, certbot, backup"
docker-compose logs -f "$SERVICE"
EOF
    
    # Status script
    cat > status.sh <<'EOF'
#!/bin/bash
echo "=== Docker Compose Services Status ==="
docker-compose ps
echo ""
echo "=== Container Health Status ==="
docker ps --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"
echo ""
echo "=== Disk Usage ==="
echo "Backup directory:"
du -sh /var/backup/speed-test-server 2>/dev/null || echo "Backup directory not found"
echo "Docker volumes:"
docker system df
EOF
    
    # Manual backup script
    cat > backup-now.sh <<EOF
#!/bin/bash

# Parse command line arguments
FORCE_NO_TTY=false
while [[ \$# -gt 0 ]]; do
    case \$1 in
        --no-tty)
            FORCE_NO_TTY=true
            export DOCKER_NONINTERACTIVE=1
            shift
            ;;
        *)
            shift
            ;;
    esac
done

# Docker Compose wrapper for non-interactive environments
docker_exec() {
    if [[ "\${FORCE_NO_TTY}" == "true" ]] || [[ "\${DOCKER_NONINTERACTIVE}" == "1" ]]; then
        docker-compose exec -T "\$@"
    elif [ -t 0 ]; then
        docker-compose exec "\$@"
    else
        docker-compose exec -T "\$@"
    fi
}

echo "Running manual backup..."
docker_exec mysql sh -c "
    mysqldump -u speedtest -p${MYSQL_DB_PASSWORD} speedtest > /var/backup/manual_backup_\$(date +%Y%m%d_%H%M%S).sql &&
    gzip /var/backup/manual_backup_\$(date +%Y%m%d_%H%M%S).sql &&
    echo 'Manual backup completed successfully'
"
echo "Backup saved to $BACKUP_DIR"
ls -lah $BACKUP_DIR/manual_backup_*.sql.gz | tail -5
EOF
    
    # Restore script
    cat > restore.sh <<'EOF'
#!/bin/bash

# Parse command line arguments
FORCE_NO_TTY=false
BACKUP_FILE=""

while [[ $# -gt 0 ]]; do
    case $1 in
        --no-tty)
            FORCE_NO_TTY=true
            export DOCKER_NONINTERACTIVE=1
            shift
            ;;
        *)
            if [[ -z "$BACKUP_FILE" ]]; then
                BACKUP_FILE="$1"
            fi
            shift
            ;;
    esac
done

# Docker Compose wrapper for non-interactive environments
docker_exec() {
    if [[ "${FORCE_NO_TTY}" == "true" ]] || [[ "${DOCKER_NONINTERACTIVE}" == "1" ]]; then
        docker-compose exec -T "$@"
    elif [ -t 0 ]; then
        docker-compose exec "$@"
    else
        docker-compose exec -T "$@"
    fi
}

if [[ -z "$BACKUP_FILE" ]]; then
    echo "Usage: $0 [--no-tty] <backup_file.sql.gz>"
    echo "Available backups:"
    ls -lah /var/backup/speed-test-server/*.sql.gz 2>/dev/null || echo "No backups found"
    exit 1
fi

BACKUP_FILE="$1"
if [[ ! -f "$BACKUP_FILE" ]]; then
    echo "Backup file not found: $BACKUP_FILE"
    exit 1
fi

echo "Restoring database from: $BACKUP_FILE"
echo "WARNING: This will overwrite the current database!"
read -p "Are you sure? (yes/no): " -r
if [[ $REPLY == "yes" ]]; then
    docker_exec mysql sh -c "
        zcat /var/backup/$(basename $BACKUP_FILE) | mysql -u speedtest -p${MYSQL_DB_PASSWORD} speedtest
    "
    echo "Database restored successfully"
else
    echo "Restore cancelled"
fi
EOF
    
    # SSL renewal script
    cat > renew-ssl.sh <<'EOF'
#!/bin/bash

# Parse command line arguments
FORCE_NO_TTY=false
while [[ $# -gt 0 ]]; do
    case $1 in
        --no-tty)
            FORCE_NO_TTY=true
            export DOCKER_NONINTERACTIVE=1
            shift
            ;;
        *)
            shift
            ;;
    esac
done

# Docker Compose wrapper for non-interactive environments
docker_exec() {
    if [[ "${FORCE_NO_TTY}" == "true" ]] || [[ "${DOCKER_NONINTERACTIVE}" == "1" ]]; then
        docker-compose exec -T "$@"
    elif [ -t 0 ]; then
        docker-compose exec "$@"
    else
        docker-compose exec -T "$@"
    fi
}

echo "Renewing SSL certificates..."
docker-compose run --rm certbot renew
docker_exec nginx nginx -s reload
echo "SSL renewal completed"
EOF
    
    # Update script
    cat > update.sh <<'EOF'
#!/bin/bash
echo "Updating Krea Speed Test Server..."
echo "1. Pulling latest images..."
docker-compose pull
echo "2. Rebuilding application..."
docker-compose build --no-cache app
echo "3. Restarting services..."
docker-compose up -d
echo "Update completed!"
EOF
    
    chmod +x start.sh stop.sh restart.sh logs.sh status.sh backup-now.sh restore.sh renew-ssl.sh update.sh version.sh
    log_success "Management scripts created"
}

copy_application_files() {
    log_info "Copying application files..."
    
    # Copy application files from /tmp/speed-test-server if they exist
    if [[ -d "/tmp/speed-test-server" ]]; then
        cp -r /tmp/speed-test-server/* .
        log_success "Application files copied from /tmp/speed-test-server"
    else
        log_error "Application files not found in /tmp/speed-test-server"
        log_error "Please copy your project files to /tmp/speed-test-server before running this script"
        exit 1
    fi
}

setup_ssl_auto_renewal() {
    log_info "Setting up SSL auto-renewal (every 80 days)..."
    
    # Create SSL renewal cron job
    cat > /etc/cron.d/ssl-renewal <<EOF
# SSL Certificate Auto-Renewal for Krea Speed Test Server
# Runs every 40 days to ensure certificates are renewed before expiration
0 3 */40 * * root cd /opt/${APP_NAME} && ./renew-ssl.sh >> ${BACKUP_DIR}/ssl-renewal.log 2>&1
EOF
    
    log_success "SSL auto-renewal configured"
}

deploy_services() {
    log_info "Deploying services with Docker Compose..."
    
    # Check if we're in an interactive environment
    if [ -t 0 ]; then
        DOCKER_COMPOSE_FLAGS=""
    else
        export COMPOSE_INTERACTIVE_NO_CLI=1
        DOCKER_COMPOSE_FLAGS=""
    fi
    
    # Build and start services
    docker-compose build
    docker-compose up -d mysql
    
    # Wait for MySQL to be ready
    log_info "Waiting for MySQL to be ready..."
    sleep 30
    
    # Start application
    docker-compose up -d app
    
    # Wait for application to be ready
    log_info "Waiting for application to be ready..."
    sleep 20
    
    # Start nginx (without SSL first)
    docker-compose up -d nginx
    
    # Initialize SSL certificates
    log_info "Initializing SSL certificates..."
    sleep 10
    docker-compose run --rm certbot
    
    # Reload nginx with SSL
    docker_exec nginx nginx -s reload
    
    # Start backup service
    docker-compose up -d backup
    
    log_success "All services deployed and running"
}

setup_admin_user() {
    log_info "Setting up admin user and API key..."
    
    # Wait for services to be fully ready
    sleep 10
    
    # Insert admin API key into database
    docker_exec mysql mysql -u speedtest -p"$MYSQL_DB_PASSWORD" speedtest <<EOF
INSERT INTO api_keys (api_key, name, is_active, rate_limit_per_hour, created_at, updated_at) 
VALUES ('$ADMIN_API_KEY', 'admin', 1, 10000, NOW(), NOW()) 
ON DUPLICATE KEY UPDATE 
name='admin', is_active=1, rate_limit_per_hour=10000, updated_at=NOW();
EOF
    
    log_success "Admin user configured"
}

display_deployment_summary() {
    echo ""
    log_success "🎉 DOCKER DEPLOYMENT COMPLETE! 🎉"
    echo "========================================="
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
    echo -e "${BLUE}📁 IMPORTANT LOCATIONS:${NC}"
    echo "  Application: /opt/$APP_NAME"
    echo "  Daily Backups: $BACKUP_DIR"
    echo "  Docker Volumes: /var/lib/docker/volumes"
    echo ""
    echo -e "${BLUE}🔧 MANAGEMENT COMMANDS:${NC}"
    echo "  Start services: ./start.sh"
    echo "  Stop services: ./stop.sh"
    echo "  Restart services: ./restart.sh"
    echo "  View logs: ./logs.sh [service]"
    echo "  Service status: ./status.sh"
    echo "  Manual backup: ./backup-now.sh"
    echo "  Restore backup: ./restore.sh <backup_file>"
    echo "  Renew SSL: ./renew-ssl.sh"
    echo "  Update application: ./update.sh"
    echo ""
    echo -e "${BLUE}🔄 AUTO-RESTART & BACKUP:${NC}"
    echo "  ✅ All containers have restart policy: unless-stopped"
    echo "  ✅ Daily MySQL backups at 2:00 AM"
    echo "  ✅ SSL auto-renewal every 40 days"
    echo "  ✅ Backup retention: 30 days"
    echo ""
    echo -e "${YELLOW}💾 SAVE THESE CREDENTIALS SECURELY!${NC}"
    echo ""
    
    # Save deployment information
    cat > DEPLOYMENT_INFO.txt <<EOF
Krea Speed Test Server - Docker Production Deployment
====================================================

Domain: $DOMAIN
Email: $EMAIL
Deployed: $(date)
Backup Directory: $BACKUP_DIR

CREDENTIALS:
MySQL Root Password: $MYSQL_ROOT_PASSWORD
MySQL App Password: $MYSQL_DB_PASSWORD
Admin API Key: $ADMIN_API_KEY

URLS:
Application: https://$DOMAIN
Swagger Docs: https://$DOMAIN/swagger/index.html
Health Check: https://$DOMAIN/healthz

MANAGEMENT COMMANDS:
Start: ./start.sh
Stop: ./stop.sh
Restart: ./restart.sh
Logs: ./logs.sh [service]
Status: ./status.sh
Manual Backup: ./backup-now.sh
Restore: ./restore.sh <backup_file>
SSL Renewal: ./renew-ssl.sh
Update: ./update.sh

AUTO-FEATURES:
- Container auto-restart (unless-stopped policy)
- Daily MySQL backups at 2:00 AM
- SSL certificate auto-renewal every 40 days
- 30-day backup retention

TROUBLESHOOTING:
If you see "the input device is not a TTY" errors:
1. Use the --no-tty flag: ./deploy.sh --no-tty yourdomain.com
2. Or use the wrapper: ./deploy-no-tty.sh yourdomain.com
3. Or try: export DOCKER_NONINTERACTIVE=1
4. For individual commands: ./backup-now.sh --no-tty

For deployment issues:
- Check Docker is running: docker --version
- Check Docker Compose: docker-compose --version
- View logs: ./logs.sh [service]
- Check status: ./status.sh
- Health checks for all services

BACKUP LOCATION: $BACKUP_DIR
EOF
    
    chmod 600 DEPLOYMENT_INFO.txt
    log_success "Deployment info saved to /opt/$APP_NAME/DEPLOYMENT_INFO.txt"
}

# Main execution
main() {
    log_info "🚀 Starting Krea Speed Test Server Docker Deployment"
    echo "===================================================="
    
    check_root
    check_domain
    cleanup_conflicting_files
    check_prerequisites
    install_docker
    create_directories
    copy_application_files
    create_environment_file
    create_docker_compose
    create_nginx_config
    create_backup_script
    create_management_scripts
    setup_ssl_auto_renewal
    deploy_services
    setup_admin_user
    display_deployment_summary
    
    log_success "🎉 Docker deployment completed successfully!"
    log_info "Your application is now running at https://$DOMAIN"
    log_info "Daily backups will be stored in $BACKUP_DIR"
}

# Run main function
main "$@"
