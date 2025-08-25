#!/bin/bash

# Fix Application Files Missing Issue
# This script resolves the issue where nginx returns 404 because the Go application isn't running

set -e

echo "🔧 Fixing Application Files Issue..."
echo "=================================="

# Check if we're in the deployment directory
if [[ ! -f "docker-compose.yml" ]]; then
    echo "❌ docker-compose.yml not found. Please run this from the deployment directory (/opt/speed-test-server)."
    exit 1
fi

echo ""
echo "1. Checking current container status..."
docker-compose ps

echo ""
echo "2. Checking if Go application files exist..."
if [[ -f "go.mod" ]] && [[ -f "cmd/speed-test-server/main.go" ]]; then
    echo "✅ Go application files found"
else
    echo "❌ Go application files missing - downloading from repository..."
    
    # Download fresh copy of application files
    cd /tmp
    rm -rf speed-test 2>/dev/null || true
    git clone https://github.com/Krea-University/speed-test.git
    
    # Copy files to deployment directory
    cd /opt/speed-test-server
    cp -r /tmp/speed-test/* .
    
    echo "✅ Application files downloaded and copied"
fi

echo ""
echo "3. Checking application container logs..."
echo "Recent application logs:"
docker-compose logs app --tail=20

echo ""
echo "4. Rebuilding application container..."
docker-compose stop app
docker-compose build --no-cache app

echo ""
echo "5. Starting application container..."
docker-compose up -d app

echo ""
echo "6. Waiting for application to start..."
sleep 10

echo ""
echo "7. Testing application health..."
for i in {1..10}; do
    if docker-compose exec -T app wget --spider --quiet http://localhost:8080/healthz 2>/dev/null; then
        echo "✅ Application is responding on port 8080"
        break
    else
        echo "⏳ Waiting for application to respond... (attempt $i/10)"
        sleep 2
    fi
done

echo ""
echo "8. Testing nginx proxy..."
if curl -f "http://localhost/" 2>/dev/null; then
    echo "✅ Nginx is successfully proxying to application"
else
    echo "⚠️  Nginx proxy test failed - checking configuration..."
    docker-compose logs nginx --tail=10
fi

echo ""
echo "9. Final container status:"
docker-compose ps

echo ""
echo "🎉 Application fix completed!"
echo ""
echo "🔍 Troubleshooting commands:"
echo "- Check app logs: docker-compose logs app"
echo "- Check nginx logs: docker-compose logs nginx"
echo "- Test app directly: docker-compose exec app wget -qO- http://localhost:8080/healthz"
echo "- Restart all services: docker-compose restart"
