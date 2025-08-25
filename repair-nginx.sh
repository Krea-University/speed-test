#!/bin/bash

# Repair Script for Nginx SSL Issues
# This script fixes nginx containers stuck in restart loops due to missing SSL certificates

set -e

echo "🔧 Repairing Nginx SSL Configuration..."
echo "====================================="

# Check if we're in the right directory
if [[ ! -f "docker-compose.yml" ]]; then
    echo "❌ docker-compose.yml not found. Please run this from the deployment directory."
    exit 1
fi

# Get domain from docker-compose.yml or ask user
DOMAIN=$(grep -o 'server_name .*;' nginx.conf 2>/dev/null | head -1 | sed 's/server_name //; s/;//' || echo "")
if [[ -z "$DOMAIN" ]]; then
    read -p "Enter your domain name: " DOMAIN
fi

echo "Domain: $DOMAIN"

# Stop nginx container if it's running
echo "🛑 Stopping nginx container..."
docker-compose stop nginx || true

# Create HTTP-only nginx configuration
echo "📝 Creating HTTP-only nginx configuration..."
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
                    '"\$http_user_agent" "\$http_x_forwarded_for"';

    access_log /var/log/nginx/access.log main;
    error_log /var/log/nginx/error.log warn;

    # Performance
    sendfile on;
    tcp_nopush on;
    tcp_nodelay on;
    keepalive_timeout 65;
    client_max_body_size 100M;
    
    # Rate limiting zones
    limit_req_zone \$binary_remote_addr zone=api:10m rate=10r/s;
    limit_req_zone \$binary_remote_addr zone=general:10m rate=30r/s;

    # HTTP server
    server {
        listen 80;
        server_name ${DOMAIN};

        # Let's Encrypt challenge
        location /.well-known/acme-challenge/ {
            root /var/www/certbot;
        }

        # Application traffic (temporarily on HTTP until SSL is set up)
        location / {
            limit_req zone=general burst=50 nodelay;
            
            proxy_pass http://app:8080;
            proxy_http_version 1.1;
            proxy_set_header Host \$host;
            proxy_set_header X-Real-IP \$remote_addr;
            proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
            proxy_set_header X-Forwarded-Proto \$scheme;
            
            proxy_connect_timeout 30s;
            proxy_send_timeout 30s;
            proxy_read_timeout 30s;
        }

        # API endpoints
        location /api/ {
            limit_req zone=api burst=20 nodelay;
            limit_req_status 429;
            
            proxy_pass http://app:8080;
            proxy_http_version 1.1;
            proxy_set_header Host \$host;
            proxy_set_header X-Real-IP \$remote_addr;
            proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
            proxy_set_header X-Forwarded-Proto \$scheme;
            
            proxy_connect_timeout 30s;
            proxy_send_timeout 30s;
            proxy_read_timeout 30s;
        }

        # WebSocket support
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
            
            proxy_read_timeout 3600s;
            proxy_send_timeout 3600s;
        }

        # Health check endpoint
        location /healthz {
            proxy_pass http://app:8080;
            access_log off;
        }
    }
}
EOF

echo "✅ HTTP-only nginx configuration created"

# Start nginx container
echo "🚀 Starting nginx container..."
docker-compose up -d nginx

# Wait for nginx to start
sleep 5

# Check nginx status
if docker-compose ps nginx | grep -q "Up"; then
    echo "✅ Nginx is now running successfully!"
    echo ""
    echo "📋 Next Steps:"
    echo "1. Test your site: http://$DOMAIN"
    echo "2. Run diagnostics: ./diagnose.sh $DOMAIN"
    echo "3. Setup SSL: ./setup-ssl-manual.sh $DOMAIN"
    echo ""
    echo "📊 Current Status:"
    docker-compose ps nginx
else
    echo "❌ Nginx failed to start. Checking logs..."
    docker-compose logs nginx
    exit 1
fi

echo ""
echo "🎉 Repair completed successfully!"
echo "Your site is now accessible at: http://$DOMAIN"
