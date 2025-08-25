#!/bin/bash

# Database Connectivity Fix for Krea Speed Test Server
# This script resolves database connection issues between app and mysql containers

set -e

echo "🔧 Fixing Database Connectivity Issue..."
echo "======================================="

# Check if we're in the deployment directory
if [[ ! -f "docker-compose.yml" ]]; then
    echo "❌ docker-compose.yml not found. Please run this from the deployment directory (/opt/speed-test-server)."
    exit 1
fi

echo ""
echo "1. Checking current container status..."
docker-compose ps

echo ""
echo "2. Testing MySQL container accessibility..."
if docker-compose exec -T mysql mysql -u root -p"${MYSQL_ROOT_PASSWORD:-$(grep MYSQL_ROOT_PASSWORD .env | cut -d'=' -f2)}" -e "SELECT 1;" > /dev/null 2>&1; then
    echo "✅ MySQL container is accessible"
else
    echo "❌ MySQL container is not accessible"
    echo "Starting MySQL container..."
    docker-compose up -d mysql
    echo "Waiting for MySQL to be ready..."
    sleep 15
fi

echo ""
echo "3. Testing network connectivity from app to mysql..."
if docker-compose exec -T app ping -c 1 mysql > /dev/null 2>&1; then
    echo "✅ App container can reach mysql container"
else
    echo "❌ Network connectivity issue detected"
    echo "Recreating containers with proper network..."
    docker-compose down
    docker-compose up -d mysql
    sleep 15
    docker-compose up -d app
    sleep 10
fi

echo ""
echo "4. Checking environment variables in app container..."
echo "Database URL from app container:"
docker-compose exec -T app env | grep DATABASE_URL || echo "DATABASE_URL not set"

echo ""
echo "5. Testing database connection from app container..."
if docker-compose exec -T app sh -c 'command -v mysql' > /dev/null 2>&1; then
    echo "Testing direct mysql connection from app container..."
    MYSQL_PASSWORD=$(grep MYSQL_PASSWORD .env | cut -d'=' -f2)
    if docker-compose exec -T app mysql -h mysql -u speedtest -p"$MYSQL_PASSWORD" speedtest -e "SELECT 1;" > /dev/null 2>&1; then
        echo "✅ Database connection successful from app container"
    else
        echo "❌ Database connection failed from app container"
    fi
else
    echo "MySQL client not available in app container - this is normal for production builds"
fi

echo ""
echo "6. Checking application logs for database connection..."
echo "Recent application logs:"
docker-compose logs app --tail=15

echo ""
echo "7. Restarting application to retry database connection..."
docker-compose restart app
echo "Waiting for application to restart..."
sleep 10

echo ""
echo "8. Checking final application status..."
echo "Latest application logs:"
docker-compose logs app --tail=10

echo ""
echo "9. Testing application health endpoint..."
for i in {1..5}; do
    if curl -s "http://localhost:8080/healthz" > /dev/null 2>&1; then
        echo "✅ Application health check passed"
        break
    else
        echo "⏳ Waiting for application health check... (attempt $i/5)"
        sleep 3
    fi
done

echo ""
echo "10. Final status check..."
docker-compose ps

echo ""
echo "🎉 Database connectivity fix completed!"
echo ""
echo "🔍 If database issues persist:"
echo "- Check logs: docker-compose logs app"
echo "- Check MySQL: docker-compose logs mysql"
echo "- Run database setup: ./setup-database.sh"
echo "- Restart all: docker-compose restart"
echo ""
echo "🌐 Test your application:"
echo "- Health check: curl http://your-server-ip:8080/healthz"
echo "- Web interface: http://your-server-ip/"
