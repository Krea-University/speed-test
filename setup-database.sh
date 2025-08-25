#!/bin/bash

# Database Setup and Troubleshooting Script for Krea Speed Test Server
# This script helps verify and fix database setup issues

set -e

echo "🔧 Database Setup & Troubleshooting Tool"
echo "========================================"

# Check if we're in the right directory
if [[ ! -f "docker-compose.yml" ]]; then
    echo "❌ docker-compose.yml not found. Please run this from the deployment directory."
    exit 1
fi

# Load environment variables
if [[ -f ".env" ]]; then
    source .env
    echo "✅ Environment variables loaded"
else
    echo "❌ .env file not found"
    exit 1
fi

echo ""
echo "1. Checking MySQL container status..."
if docker-compose ps mysql | grep -q "Up"; then
    echo "✅ MySQL container is running"
else
    echo "❌ MySQL container is not running"
    echo "Starting MySQL container..."
    docker-compose up -d mysql
    echo "Waiting for MySQL to start..."
    sleep 10
fi

echo ""
echo "2. Testing MySQL root connection..."
if docker-compose exec -T mysql mysql -u root -p"$MYSQL_ROOT_PASSWORD" -e "SELECT 1;" > /dev/null 2>&1; then
    echo "✅ MySQL root connection successful"
else
    echo "❌ MySQL root connection failed"
    echo "MySQL root password from .env: $MYSQL_ROOT_PASSWORD"
    exit 1
fi

echo ""
echo "3. Checking if speedtest database exists..."
if docker-compose exec -T mysql mysql -u root -p"$MYSQL_ROOT_PASSWORD" -e "USE speedtest; SELECT 1;" > /dev/null 2>&1; then
    echo "✅ speedtest database exists"
else
    echo "❌ speedtest database not found"
    echo "Creating speedtest database..."
    docker-compose exec -T mysql mysql -u root -p"$MYSQL_ROOT_PASSWORD" -e "CREATE DATABASE IF NOT EXISTS speedtest;"
    echo "✅ speedtest database created"
fi

echo ""
echo "4. Checking if speedtest user exists..."
if docker-compose exec -T mysql mysql -u root -p"$MYSQL_ROOT_PASSWORD" -e "SELECT User FROM mysql.user WHERE User='speedtest';" | grep -q "speedtest"; then
    echo "✅ speedtest user exists"
else
    echo "❌ speedtest user not found"
    echo "Creating speedtest user..."
    docker-compose exec -T mysql mysql -u root -p"$MYSQL_ROOT_PASSWORD" <<EOF
CREATE USER IF NOT EXISTS 'speedtest'@'%' IDENTIFIED BY '$MYSQL_PASSWORD';
GRANT ALL PRIVILEGES ON speedtest.* TO 'speedtest'@'%';
FLUSH PRIVILEGES;
EOF
    echo "✅ speedtest user created and granted permissions"
fi

echo ""
echo "5. Testing speedtest user connection..."
if docker-compose exec -T mysql mysql -u speedtest -p"$MYSQL_PASSWORD" speedtest -e "SELECT 1;" > /dev/null 2>&1; then
    echo "✅ speedtest user connection successful"
else
    echo "❌ speedtest user connection failed"
    echo "Recreating speedtest user with correct permissions..."
    docker-compose exec -T mysql mysql -u root -p"$MYSQL_ROOT_PASSWORD" <<EOF
DROP USER IF EXISTS 'speedtest'@'%';
CREATE USER 'speedtest'@'%' IDENTIFIED BY '$MYSQL_PASSWORD';
GRANT ALL PRIVILEGES ON speedtest.* TO 'speedtest'@'%';
FLUSH PRIVILEGES;
EOF
    echo "✅ speedtest user recreated"
fi

echo ""
echo "6. Checking database tables..."
if docker-compose exec -T mysql mysql -u speedtest -p"$MYSQL_PASSWORD" speedtest -e "SHOW TABLES;" > /dev/null 2>&1; then
    echo "✅ Can access speedtest database"
    echo "Tables in database:"
    docker-compose exec -T mysql mysql -u speedtest -p"$MYSQL_PASSWORD" speedtest -e "SHOW TABLES;"
else
    echo "❌ Cannot access speedtest database tables"
    exit 1
fi

echo ""
echo "7. Checking if api_keys table exists..."
if docker-compose exec -T mysql mysql -u speedtest -p"$MYSQL_PASSWORD" speedtest -e "DESCRIBE api_keys;" > /dev/null 2>&1; then
    echo "✅ api_keys table exists"
    echo "Table structure:"
    docker-compose exec -T mysql mysql -u speedtest -p"$MYSQL_PASSWORD" speedtest -e "DESCRIBE api_keys;"
else
    echo "❌ api_keys table not found"
    echo "Creating api_keys table..."
    docker-compose exec -T mysql mysql -u speedtest -p"$MYSQL_PASSWORD" speedtest <<'EOF'
CREATE TABLE IF NOT EXISTS api_keys (
    api_key VARCHAR(64) PRIMARY KEY,
    name VARCHAR(255) NOT NULL,
    description TEXT,
    rate_limit_per_hour INT DEFAULT 1000,
    is_active BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
);
EOF
    echo "✅ api_keys table created"
fi

echo ""
echo "8. Setting up admin API key..."
ADMIN_API_KEY="${ADMIN_API_KEY:-$(openssl rand -hex 32)}"
if docker-compose exec -T mysql mysql -u speedtest -p"$MYSQL_PASSWORD" speedtest <<EOF
INSERT INTO api_keys (api_key, name, is_active, rate_limit_per_hour, created_at, updated_at) 
VALUES ('$ADMIN_API_KEY', 'admin', 1, 10000, NOW(), NOW()) 
ON DUPLICATE KEY UPDATE 
name='admin', is_active=1, rate_limit_per_hour=10000, updated_at=NOW();
EOF
then
    echo "✅ Admin API key configured successfully"
else
    echo "❌ Failed to configure admin API key"
    exit 1
fi

echo ""
echo "9. Verifying admin API key..."
if docker-compose exec -T mysql mysql -u speedtest -p"$MYSQL_PASSWORD" speedtest -e "SELECT api_key, name, is_active FROM api_keys WHERE name='admin';" | grep -q "admin"; then
    echo "✅ Admin API key verified in database"
    echo "API Key details:"
    docker-compose exec -T mysql mysql -u speedtest -p"$MYSQL_PASSWORD" speedtest -e "SELECT api_key, name, is_active, rate_limit_per_hour FROM api_keys WHERE name='admin';"
else
    echo "❌ Admin API key not found in database"
    exit 1
fi

echo ""
echo "🎉 Database Setup Complete!"
echo "=========================="
echo ""
echo "Database Connection Details:"
echo "- Host: localhost (from host), mysql (from containers)"
echo "- Port: 3306"
echo "- Database: speedtest"
echo "- Username: speedtest"
echo "- Password: $MYSQL_PASSWORD"
echo ""
echo "Admin API Key: $ADMIN_API_KEY"
echo ""
echo "💾 Save this information securely!"

# Update .env file with admin API key if not present
if ! grep -q "ADMIN_API_KEY=" .env; then
    echo "ADMIN_API_KEY=$ADMIN_API_KEY" >> .env
    echo "✅ ADMIN_API_KEY added to .env file"
fi
